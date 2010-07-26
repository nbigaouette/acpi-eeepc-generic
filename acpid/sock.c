/*
 *  sock.c - ACPI daemon socket interface
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
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <grp.h>

#include "acpid.h"
#include "event.h"
#include "ud_socket.h"
#include "connection_list.h"

const char *socketfile = ACPID_SOCKETFILE;
const char *socketgroup;
mode_t socketmode = ACPID_SOCKETMODE;
int clientmax = ACPID_CLIENTMAX;

/* the number of non-root clients that are connected */
int non_root_clients;

static void
process_sock(int fd)
{
	int cli_fd;
	struct ucred creds;
	char buf[32];
	static int accept_errors;

	/* accept and add to our lists */
	cli_fd = ud_accept(fd, &creds);
	if (cli_fd < 0) {
		acpid_log(LOG_ERR, "can't accept client: %s\n",
			  strerror(errno));
		accept_errors++;
		if (accept_errors >= 5) {
			acpid_log(LOG_ERR, "giving up\n");
			clean_exit_with_status(EXIT_FAILURE);
		}
		return;
	}
	accept_errors = 0;
	/* This check against clientmax is from the non-netlink 1.0.10.  */
	if (creds.uid != 0 && non_root_clients >= clientmax) {
		close(cli_fd);
		acpid_log(LOG_ERR,
		    "too many non-root clients\n");
		return;
	}
	if (creds.uid != 0) {
		non_root_clients++;
	}
	fcntl(cli_fd, F_SETFD, FD_CLOEXEC);
	snprintf(buf, sizeof(buf)-1, "%d[%d:%d]",
		 creds.pid, creds.uid, creds.gid);
	acpid_add_client(cli_fd, buf);
}

void
open_sock()
{
	int fd;
	struct connection c;

	fd = ud_create_socket(socketfile);
	if (fd < 0) {
		acpid_log(LOG_ERR, "can't open socket %s: %s\n",
			socketfile, strerror(errno));
		exit(EXIT_FAILURE);
	}
	fcntl(fd, F_SETFD, FD_CLOEXEC);
	chmod(socketfile, socketmode);
	if (socketgroup) {
		struct group *gr;
		struct stat buf;
		gr = getgrnam(socketgroup);
		if (!gr) {
			acpid_log(LOG_ERR, "group %s does not exist\n", socketgroup);
			exit(EXIT_FAILURE);
		}
		if (stat(socketfile, &buf) < 0) {
			acpid_log(LOG_ERR, "can't stat %s\n", socketfile);
			exit(EXIT_FAILURE);
		}
		if (chown(socketfile, buf.st_uid, gr->gr_gid) < 0) {
			acpid_log(LOG_ERR, "can't chown: %s\n", strerror(errno));
			exit(EXIT_FAILURE);
		}
	}
	
	/* add a connection to the list */
	c.fd = fd;
	c.process = process_sock;
	add_connection(&c);
}

