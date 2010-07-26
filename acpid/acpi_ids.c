/*
 *  acpi_ids.c - ACPI Netlink Group and Family IDs
 *
 *  Copyright (C) 2008 Ted Felix (www.tedfelix.com)
 *  Portions from acpi_genl Copyright (C) Zhang Rui <rui.zhang@intel.com>
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
 */

#include <stdio.h>
/* needed by netlink.h, should be in there */
#include <arpa/inet.h>
#include <linux/types.h>
#include <string.h>

#include "genetlink.h"
#include "libnetlink.h"

#include "acpid.h"

#define GENL_MAX_FAM_GRPS       256
#define ACPI_EVENT_FAMILY_NAME          "acpi_event"
#define ACPI_EVENT_MCAST_GROUP_NAME     "acpi_mc_group"

static int initialized = 0;
static __u16 acpi_event_family_id = 0;
static __u32 acpi_event_mcast_group_id = 0;

/*
 *  A CTRL_CMD_GETFAMILY message returns an attribute table that looks
 *    like this:
 *
 *  CTRL_ATTR_FAMILY_ID         Use this to make sure we get the proper msgs
 *  CTRL_ATTR_MCAST_GROUPS
 *    CTRL_ATTR_MCAST_GRP_NAME
 *    CTRL_ATTR_MCAST_GRP_ID    Need this for the group mask
 *    ...
 */

static int
get_ctrl_grp_id(struct rtattr *arg)
{
	struct rtattr *tb[CTRL_ATTR_MCAST_GRP_MAX + 1];
	char *name;

	if (arg == NULL)
		return -1;

	/* nested within the CTRL_ATTR_MCAST_GROUPS attribute are the  */
	/* group name and ID  */
	parse_rtattr_nested(tb, CTRL_ATTR_MCAST_GRP_MAX, arg);

	/* if either of the entries needed cannot be found, bail */
	if (!tb[CTRL_ATTR_MCAST_GRP_NAME] || !tb[CTRL_ATTR_MCAST_GRP_ID])
		return -1;

	/* get the name of this multicast group we've found */
	name = RTA_DATA(tb[CTRL_ATTR_MCAST_GRP_NAME]);

	/* if it does not match the ACPI event multicast group name, bail */
	if (strcmp(name, ACPI_EVENT_MCAST_GROUP_NAME))
		return -1;

	/* At this point, we've found what we were looking for.  We now  */
	/* have the multicast group ID for ACPI events over generic netlink. */
	acpi_event_mcast_group_id =
		*((__u32 *)RTA_DATA(tb[CTRL_ATTR_MCAST_GRP_ID]));

	return 0;
}

/* n = the response to a CTRL_CMD_GETFAMILY message */
static int
genl_get_mcast_group_id(struct nlmsghdr *n)
{
	/*
	 *  Attribute table.  Note the type name "rtattr" which means "route
	 *  attribute".  This is a vestige of one of netlink's main uses:
	 *  routing.
	 */
	struct rtattr *tb[CTRL_ATTR_MAX + 1];
	/* place for the generic netlink header in the incoming message */
	struct genlmsghdr ghdr;
	/* length of the attribute and payload */
	int len = n->nlmsg_len - NLMSG_LENGTH(GENL_HDRLEN);
	/* Pointer to the attribute portion of the message */
	struct rtattr *attrs;

	if (len < 0) {
		fprintf(stderr, "%s: netlink CTRL_CMD_GETFAMILY response, "
			"wrong controller message len: %d\n", progname, len);
		return -1;
	}

	if (n->nlmsg_type != GENL_ID_CTRL) {
		fprintf(stderr, "%s: not a netlink controller message, "
			"nlmsg_len=%d nlmsg_type=0x%x\n", 
			progname, n->nlmsg_len, n->nlmsg_type);
		return 0;
	}

	/* copy generic netlink header into structure */
	memcpy(&ghdr, NLMSG_DATA(n), GENL_HDRLEN);

	if (ghdr.cmd != CTRL_CMD_GETFAMILY &&
	    ghdr.cmd != CTRL_CMD_DELFAMILY &&
	    ghdr.cmd != CTRL_CMD_NEWFAMILY &&
	    ghdr.cmd != CTRL_CMD_NEWMCAST_GRP &&
	    ghdr.cmd != CTRL_CMD_DELMCAST_GRP) {
		fprintf(stderr, "%s: unknown netlink controller command %d\n",
			progname, ghdr.cmd);
		return 0;
	}

	/* set attrs to point to the attribute */
	attrs = (struct rtattr *)(NLMSG_DATA(n) + GENL_HDRLEN);
	/* Read the table from the message into "tb".  This actually just  */
	/* places pointers into the message into tb[].  */
	parse_rtattr(tb, CTRL_ATTR_MAX, attrs, len);

	/* if a family ID attribute is present, get it */
	if (tb[CTRL_ATTR_FAMILY_ID])
	{
		acpi_event_family_id =
			*((__u32 *)RTA_DATA(tb[CTRL_ATTR_FAMILY_ID]));
	}

	/* if a "multicast groups" attribute is present... */
	if (tb[CTRL_ATTR_MCAST_GROUPS]) {
		struct rtattr *tb2[GENL_MAX_FAM_GRPS + 1];
		int i;

		/* get the group table within this attribute  */
		parse_rtattr_nested(tb2, GENL_MAX_FAM_GRPS,
			tb[CTRL_ATTR_MCAST_GROUPS]);

		/* for each group */
		for (i = 0; i < GENL_MAX_FAM_GRPS; i++)
			/* if this group is valid */
			if (tb2[i])
				/* Parse the ID.  If successful, we're done. */
				if (!get_ctrl_grp_id(tb2[i]))
					return 0;
	}

	return -1;
}

static int
genl_get_ids(char *family_name)
{
	/* handle to the netlink connection */
	struct rtnl_handle rth;
	/* holds the request we are going to send and the reply */
	struct {
		struct nlmsghdr n;
		char buf[4096];    /* ??? Is this big enough for all cases? */
	} req;
	/* pointer to the nlmsghdr in req */
	struct nlmsghdr *nlh;
	/* place for the generic netlink header before copied into req */
	struct genlmsghdr ghdr;
	/* return value */
	int ret = -1;

	/* clear out the request */
	memset(&req, 0, sizeof(req));

	/* set up nlh to point to the netlink header in req */
	nlh = &req.n;
	/* set up the netlink header */
	nlh->nlmsg_len = NLMSG_LENGTH(GENL_HDRLEN);
	nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	nlh->nlmsg_type = GENL_ID_CTRL;

	/* clear out the generic netlink message header */
	memset(&ghdr, 0, sizeof(struct genlmsghdr));
	/* set the command we want to run: "GETFAMILY" */
	ghdr.cmd = CTRL_CMD_GETFAMILY;
	/* copy it into req */
	memcpy(NLMSG_DATA(&req.n), &ghdr, GENL_HDRLEN);

	/* the message payload is the family name */
	addattr_l(nlh, 128, CTRL_ATTR_FAMILY_NAME,
			  family_name, strlen(family_name) + 1);

	/* open a generic netlink connection */
	if (rtnl_open_byproto(&rth, 0, NETLINK_GENERIC) < 0) {
		fprintf(stderr, "%s: cannot open generic netlink socket\n", 
			progname);
		return -1;
	}

	/*
	 *  Send CTRL_CMD_GETFAMILY message (in nlh) to the generic
	 *  netlink controller.  Reply will be in nlh upon return.
	 */
	if (rtnl_talk(&rth, nlh, 0, 0, nlh, NULL, NULL) < 0) {
		fprintf(stderr, "%s: error talking to the kernel via netlink\n",
			progname);
		goto ctrl_done;
	}

	/* process the response */
	if (genl_get_mcast_group_id(nlh) < 0) {
		fprintf(stderr, "%s: failed to get acpi_event netlink "
			"multicast group\n", progname);
		goto ctrl_done;
	}

	ret = 0;

ctrl_done:
	rtnl_close(&rth);
	return ret;
}

/* initialize the ACPI IDs */
static void
acpi_ids_init()
{
	genl_get_ids(ACPI_EVENT_FAMILY_NAME);

	initialized = 1;
}

/* returns the netlink family ID for ACPI event messages */
__u16
acpi_ids_getfamily()
{
	/* if the IDs haven't been initialized, initialize them */
	if (initialized == 0)
		acpi_ids_init();

	return acpi_event_family_id;
}

/* returns the netlink multicast group ID for ACPI event messages */
__u32
acpi_ids_getgroup()
{
	/* if the IDs haven't been initialized, initialize them */
	if (initialized == 0)
		acpi_ids_init();

	return acpi_event_mcast_group_id;
}
