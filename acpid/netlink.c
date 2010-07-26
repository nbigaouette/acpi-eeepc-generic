/*
 *  netlink.c - Kernel ACPI Event Netlink Interface
 *
 *  Handles the details of getting kernel ACPI events from netlink.
 *
 *  Inspired by (and in some cases blatantly lifted from) Zhang Rui's
 *  acpi_genl and Alexey Kuznetsov's libnetlink.  Thanks also to Yi Yang
 *  at intel.
 *
 *  Copyright (C) 2008, Ted Felix (www.tedfelix.com)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *  (tabs at 4)
 */

/* system */
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* local */
#include "acpid.h"
#include "event.h"

#include "libnetlink.h"
#include "genetlink.h"
#include "acpi_genetlink.h"

#include "acpi_ids.h"
#include "connection_list.h"

static void
format_netlink(struct nlmsghdr *msg)
{
	struct rtattr *tb[ACPI_GENL_ATTR_MAX + 1];
	struct genlmsghdr *ghdr = NLMSG_DATA(msg);
	int len;
	struct rtattr *attrs;
	
	len = msg->nlmsg_len;
	
	/* if this message doesn't have the proper family ID, drop it */
	if (msg->nlmsg_type != acpi_ids_getfamily()) {
		if (logevents) {
			acpid_log(LOG_INFO, "wrong netlink family ID.\n");
		}
		return;
	}

	len -= NLMSG_LENGTH(GENL_HDRLEN);

	if (len < 0) {
		acpid_log(LOG_WARNING,
			"wrong netlink controller message len: %d\n", len);
		return;
	}

	attrs = (struct rtattr *)((char *)ghdr + GENL_HDRLEN);
	/* parse the attributes in this message */
	parse_rtattr(tb, ACPI_GENL_ATTR_MAX, attrs, len);

	/* if there's an ACPI event attribute... */
	if (tb[ACPI_GENL_ATTR_EVENT]) {
		/* get the actual event struct */
		struct acpi_genl_event *event =
				RTA_DATA(tb[ACPI_GENL_ATTR_EVENT]);
		char buf[64];

		/* format it */
		snprintf(buf, sizeof(buf), "%s %s %08x %08x",
			event->device_class, event->bus_id, event->type, event->data);

		/* if we're locked, don't process the event */
		if (locked()) {
			if (logevents) {
				acpid_log(LOG_INFO,
					"lockfile present, not processing "
					"netlink event \"%s\"\n", buf);
			}
			return;
		}

		if (logevents)
			acpid_log(LOG_INFO,
				"received netlink event \"%s\"\n", buf);

		/* send the event off to the handler */
		acpid_handle_event(buf);

		if (logevents)
			acpid_log(LOG_INFO,
				"completed netlink event \"%s\"\n", buf);
	}
}

/* (based on rtnl_listen() in libnetlink.c) */
void
process_netlink(int fd)
{
	int status;
	struct nlmsghdr *h;
	/* the address for recvmsg() */
	struct sockaddr_nl nladdr;
	/* the io vector for recvmsg() */
	struct iovec iov;
	/* recvmsg() parameters */
	struct msghdr msg = {
		.msg_name = &nladdr,
		.msg_namelen = sizeof(nladdr),
		.msg_iov = &iov,
		.msg_iovlen = 1,
	};
	/* buffer for the incoming data */
	char buf[8192];
	static int nerrs;

	/* set up the netlink address */
	memset(&nladdr, 0, sizeof(nladdr));
	nladdr.nl_family = AF_NETLINK;
	nladdr.nl_pid = 0;
	nladdr.nl_groups = 0;

	/* set up the I/O vector */
	iov.iov_base = buf;
	iov.iov_len = sizeof(buf);
	
	/* read the data into the buffer */
	status = recvmsg(fd, &msg, 0);

	/* if there was a problem, print a message and keep trying */
	if (status < 0) {
		/* if we were interrupted by a signal, bail */
		if (errno == EINTR)
			return;
		
		acpid_log(LOG_ERR, "netlink read error: %s (%d)\n",
			strerror(errno), errno);
		if (++nerrs >= ACPID_MAX_ERRS) {
			acpid_log(LOG_ERR,
				"too many errors reading via "
				"netlink - aborting\n");
			exit(EXIT_FAILURE);
		}
		return;
	}
	/* if an orderly shutdown has occurred, we're done */
	if (status == 0) {
		acpid_log(LOG_WARNING, "netlink connection closed\n");
		exit(EXIT_FAILURE);
	}
	/* check to see if the address length has changed */
	if (msg.msg_namelen != sizeof(nladdr)) {
		acpid_log(LOG_WARNING, "netlink unexpected length: "
			"%d   expected: %d\n", msg.msg_namelen, sizeof(nladdr));
		return;
	}
	
	/* for each message received */
	for (h = (struct nlmsghdr*)buf; (unsigned)status >= sizeof(*h); ) {
		int len = h->nlmsg_len;
		int l = len - sizeof(*h);

		if (l < 0  ||  len > status) {
			if (msg.msg_flags & MSG_TRUNC) {
				acpid_log(LOG_WARNING, "netlink msg truncated (1)\n");
				return;
			}
			acpid_log(LOG_WARNING,
				"malformed netlink msg, length %d\n", len);
			return;
		}

		/* format the message */
		format_netlink(h);

		status -= NLMSG_ALIGN(len);
		h = (struct nlmsghdr*)((char*)h + NLMSG_ALIGN(len));
	}
	if (msg.msg_flags & MSG_TRUNC) {
		acpid_log(LOG_WARNING, "netlink msg truncated (2)\n");
		return;
	}
	if (status) {
		acpid_log(LOG_WARNING, "netlink remnant of size %d\n", status);
		return;
	}

	return;
}

/* convert the netlink multicast group number into a bit map */
/* (e.g. 4 => 16, 5 => 32) */
static __u32
nl_mgrp(__u32 group)
{
	if (group > 31) {
		acpid_log(LOG_ERR, "Unexpected group number %d\n", group);
		return 0;
	}
	return group ? (1 << (group - 1)) : 0;
}

void open_netlink(void)
{
	struct rtnl_handle rth;
	struct connection c;

	/* open the appropriate netlink socket for input */
	if (rtnl_open_byproto(
		&rth, nl_mgrp(acpi_ids_getgroup()), NETLINK_GENERIC) < 0) {
		acpid_log(LOG_ERR, "cannot open generic netlink socket\n");
		return;
	}

	acpid_log(LOG_DEBUG, "netlink opened successfully\n");

	/* add a connection to the list */
	c.fd = rth.fd;
	c.process = process_netlink;
	add_connection(&c);
}

