/*
 *  proc.c - ACPI daemon proc filesystem interface
 *
 *  Portions Copyright (C) 2000 Andrew Henroid
 *  Portions Copyright (C) 2001 Sun Microsystems
 *  Portions Copyright (C) 2004 Tim Hockin (thockin@hockin.org)
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

#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "acpid.h"
#include "event.h"
#include "connection_list.h"

const char *eventfile = ACPID_EVENTFILE;

static char *read_line(int fd);

static void
process_proc(int fd)
{
	char *event;

	/* read an event */
	event = read_line(fd);

	/* if we're locked, don't process the event */
	if (locked()) {
		if (logevents  &&  event != NULL) {
			acpid_log(LOG_INFO,
				"lockfile present, not processing "
				"event \"%s\"\n", event);
		}
		return;
	}

	/* handle the event */
	if (event) {
		if (logevents) {
			acpid_log(LOG_INFO,
			          "procfs received event \"%s\"\n", event);
		}
		acpid_handle_event(event);
		if (logevents) {
			acpid_log(LOG_INFO,
				"procfs completed event \"%s\"\n", event);
		}
	} else if (errno == EPIPE) {
		acpid_log(LOG_WARNING,
			"events file connection closed\n");
		exit(EXIT_FAILURE);
	} else {
		static int nerrs;
		if (++nerrs >= ACPID_MAX_ERRS) {
			acpid_log(LOG_ERR,
				"too many errors reading "
				"events file - aborting\n");
			exit(EXIT_FAILURE);
		}
	}
}

int
open_proc()
{
	int fd;
	struct connection c;
	
	fd = open(eventfile, O_RDONLY);
	if (fd < 0) {
		if (errno == ENOENT) {
			acpid_log(LOG_INFO, "Deprecated %s was not found.  "
				"Trying netlink and the input layer...\n", eventfile);
		} else {
			acpid_log(LOG_ERR, "can't open %s: %s (%d)\n", eventfile, 
				strerror(errno), errno);
		}
		return -1;
		
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);

	acpid_log(LOG_DEBUG, "proc fs opened successfully\n");

	/* add a connection to the list */
	c.fd = fd;
	c.process = process_proc;
	add_connection(&c);

	return 0;
}

/*
 * This depends on fixes in linux ACPI after 2.4.8
 */
#define BUFLEN 1024
static char *
read_line(int fd)
{
	static char buf[BUFLEN];
	int i = 0;
	int r;
	int searching = 1;

	while (searching) {
		memset(buf+i, 0, BUFLEN-i);

		/* only go to BUFLEN-1 so there will always be a 0 at the end */
		while (i < BUFLEN-1) {
			r = read(fd, buf+i, 1);
			if (r < 0 && errno != EINTR) {
				/* we should do something with the data */
				acpid_log(LOG_ERR, "read(): %s\n",
					strerror(errno));
				return NULL;
			} else if (r == 0) {
				/* signal this in an almost standard way */
				errno = EPIPE;
				return NULL;
			} else if (r == 1) {
				/* scan for a newline */
				if (buf[i] == '\n') {
					searching = 0;
					buf[i] = '\0';
					break;
				}
				i++;
			}
		}
		if (i >= BUFLEN - 1)
			break;
	}

	return buf;
}

#if 0
/* This version leaks memory.  The above version is simpler and leak-free. */
/* Downside is that the above version always uses 1k of RAM. */
/*
 * This depends on fixes in linux ACPI after 2.4.8
 */
#define MAX_BUFLEN	1024
static char *
read_line(int fd)
{
	static char *buf;
	int buflen = 64;
	int i = 0;
	int r;
	int searching = 1;

	while (searching) {
		/* ??? This memory is leaked since it is never freed */
		buf = realloc(buf, buflen);
		if (!buf) {
			acpid_log(LOG_ERR, "malloc(%d): %s\n",
				buflen, strerror(errno));
			return NULL;
		}
		memset(buf+i, 0, buflen-i);

		while (i < buflen) {
			r = read(fd, buf+i, 1);
			if (r < 0 && errno != EINTR) {
				/* we should do something with the data */
				acpid_log(LOG_ERR, "read(): %s\n",
					strerror(errno));
				return NULL;
			} else if (r == 0) {
				/* signal this in an almost standard way */
				errno = EPIPE;
				return NULL;
			} else if (r == 1) {
				/* scan for a newline */
				if (buf[i] == '\n') {
					searching = 0;
					buf[i] = '\0';
					break;
				}
				i++;
			}
		}
		if (buflen >= MAX_BUFLEN) {
			break;
		} 
		buflen *= 2;
	}

	return buf;
}
#endif
