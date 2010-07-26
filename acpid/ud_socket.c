/*
 * $Id: ud_socket.c,v 1.6 2009/04/22 18:22:28 thockin Exp $
 * A few  routines for handling UNIX domain sockets
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <fcntl.h>

#include "acpid.h"
#include "ud_socket.h"

int
ud_create_socket(const char *name)
{
	int fd;
	int r;
	struct sockaddr_un uds_addr;

	/* JIC */
	unlink(name);

	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0) {
		return fd;
	}

	/* setup address struct */
	memset(&uds_addr, 0, sizeof(uds_addr));
	uds_addr.sun_family = AF_UNIX;
	strcpy(uds_addr.sun_path, name);
	
	/* bind it to the socket */
	r = bind(fd, (struct sockaddr *)&uds_addr, sizeof(uds_addr));
	if (r < 0) {
		return r;
	}

	/* listen - allow 10 to queue */
	r = listen(fd, 10);
	if (r < 0) {
		return r;
	}

	return fd;
}

int
ud_accept(int listenfd, struct ucred *cred)
{
	while (1) {
		int newsock = 0;
		struct sockaddr_un cliaddr;
		socklen_t len = sizeof(struct sockaddr_un);

		newsock = accept(listenfd, (struct sockaddr *)&cliaddr, &len);
		if (newsock < 0) {
			if (errno == EINTR) {
				continue; /* signal */
			}
		
			return newsock;
		}

		if (cred) {
			len = sizeof(struct ucred);
			getsockopt(newsock,SOL_SOCKET,SO_PEERCRED,cred,&len);
		}

		return newsock;
	}
}

int
ud_connect(const char *name)
{
	int fd;
	int r;
	struct sockaddr_un addr;

	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0) {
		return fd;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	sprintf(addr.sun_path, "%s", name);

	r = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
	if (r < 0) {
		close(fd);
		return r;
	}

	return fd;
}

int
ud_get_peercred(int fd, struct ucred *cred)
{
	socklen_t len = sizeof(struct ucred);
	getsockopt(fd, SOL_SOCKET, SO_PEERCRED, cred, &len);
	return 0;
}
