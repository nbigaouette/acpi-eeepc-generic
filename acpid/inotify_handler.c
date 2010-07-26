/*
 *  inotify_handler.c - inotify Handler for New Devices
 *
 *  Watches /dev/input for new input layer device files.
 *
 *  Copyright (C) 2009, Ted Felix (www.tedfelix.com)
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
#include <sys/inotify.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

/* local */
#include "acpid.h"
#include "connection_list.h"
#include "input_layer.h"

/*-----------------------------------------------------------------*/
/* called when an inotify event is received */
void process_inotify(int fd)
{
	int bytes;
	/* union to avoid strict-aliasing problems */
	union {
		char buffer[256];  /* a tad large */
		struct inotify_event event;
	} eventbuf;

	bytes = read(fd, &eventbuf.buffer, sizeof(eventbuf.buffer));

	acpid_log(LOG_DEBUG, "inotify read bytes: %d\n", bytes);

	/* eof is not expected */	
	if (bytes == 0)
	{
		acpid_log(LOG_WARNING, "inotify fd eof encountered\n");
		return;
	}
	else if (bytes < 0)
	{
		/* EINVAL means buffer wasn't big enough.  See inotify(7). */
		acpid_log(LOG_ERR, "inotify read error: %s (%d)\n",
			strerror(errno), errno);
		acpid_log(LOG_ERR, "disconnecting from inotify\n");
		delete_connection(fd);
		return;
	}

	acpid_log(LOG_DEBUG, "inotify name len: %d\n", eventbuf.event.len);

	/* if a name is included */
	if (eventbuf.event.len > 0)
	{
		const int dnsize = 256;
		char devname[dnsize];

		/* devname = ACPID_INPUTLAYERDIR + "/" + pevent -> name */
		strcpy(devname, ACPID_INPUTLAYERDIR);
		strcat(devname, "/");
		strncat(devname, eventbuf.event.name, dnsize - strlen(devname) - 1);
		
		acpid_log(LOG_DEBUG, "inotify about to open: %s\n", devname);

		open_inputfile(devname);
	}
}

/*-----------------------------------------------------------------*/
/* Set up an inotify watch on /dev/input. */
void open_inotify(void)
{
	int fd = -1;
	int wd = -1;
	struct connection c;

	/* set up inotify */
	fd = inotify_init();
	
	if (fd < 0) {
		acpid_log(LOG_ERR, "inotify_init() failed: %s (%d)\n",
			strerror(errno), errno);
		return;
	}
	
	acpid_log(LOG_DEBUG, "inotify fd: %d\n", fd);

	/* watch for new files being created in /dev/input */
	wd = inotify_add_watch(fd, ACPID_INPUTLAYERDIR, IN_CREATE);

	if (wd < 0) {
		acpid_log(LOG_ERR, "inotify_add_watch() failed: %s (%d)\n",
			strerror(errno), errno);
		close(fd);			
		return;
	}

	acpid_log(LOG_DEBUG, "inotify wd: %d\n", wd);

	/* add a connection to the list */
	c.fd = fd;
	c.process = process_inotify;
	add_connection(&c);
}

