/*
 *  acpi_listen.c - ACPI client for acpid's UNIX socket
 *
 *  Portions Copyright (C) 2003 Sun Microsystems (thockin@sun.com)
 *  Some parts (C) 2003 - Gismo / Luca Capello <luca.pca.it> http://luca.pca.it
 *  Copyright (C) 2004 Tim Hockin (thockin@hockin.org)
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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <getopt.h>
#include <time.h>
#include <sys/poll.h>
#include <grp.h>
#include <signal.h>

#include "acpid.h"
#include "ud_socket.h"

static int handle_cmdline(int *argc, char ***argv);
static char *read_line(int fd);

const char *progname;
const char *socketfile = ACPID_SOCKETFILE;
static int max_events;

static void
time_expired(int signum __attribute__((unused)))
{
	exit(EXIT_SUCCESS);
}

int
main(int argc, char **argv)
{
	int sock_fd;
	int ret;

	/* handle an alarm */
	signal(SIGALRM, time_expired);

	/* learn who we really are */
	progname = (const char *)strrchr(argv[0], '/');
	progname = progname ? (progname + 1) : argv[0];

	/* handle the commandline  */
	handle_cmdline(&argc, &argv);

	/* open the socket */
	sock_fd = ud_connect(socketfile);
	if (sock_fd < 0) {
		fprintf(stderr, "%s: can't open socket %s: %s\n",
			progname, socketfile, strerror(errno));
		exit(EXIT_FAILURE);
	}
	fcntl(sock_fd, F_SETFD, FD_CLOEXEC);

	/* set stdout to be line buffered */
	setvbuf(stdout, NULL, _IOLBF, 0);

	/* main loop */
	ret = 0;
	while (1) {
		char *event;

		/* read and handle an event */
		event = read_line(sock_fd);
		if (event) {
			fprintf(stdout, "%s\n", event);
		} else if (errno == EPIPE) {
			fprintf(stderr, "connection closed\n");
			break;
		} else {
			static int nerrs;
			if (++nerrs >= ACPID_MAX_ERRS) {
				fprintf(stderr, "too many errors - aborting\n");
				ret = 1;
				break;
			}
		}

		if (max_events > 0 && --max_events == 0) {
			break;
		}
	}

	return ret;
}

static struct option opts[] = {
	{"count", 0, 0, 'c'},
	{"socketfile", 1, 0, 's'},
	{"time", 0, 0, 't'},
	{"version", 0, 0, 'v'},
	{"help", 0, 0, 'h'},
	{NULL, 0, 0, 0},
};
static const char *opts_help[] = {
	"Set the maximum number of events.",	/* count */
	"Use the specified socket file.",	/* socketfile */
	"Listen for the specified time (in seconds).",/* time */
	"Print version information.",		/* version */
	"Print this message.",			/* help */
};

static void
usage(FILE *fp)
{
	struct option *opt;
	const char **hlp;
	int max, size;

	fprintf(fp, "Usage: %s [OPTIONS]\n", progname);
	max = 0;
	for (opt = opts; opt->name; opt++) {
		size = strlen(opt->name);
		if (size > max)
			max = size;
	}
	for (opt = opts, hlp = opts_help; opt->name; opt++, hlp++) {
		fprintf(fp, "  -%c, --%s", opt->val, opt->name);
		size = strlen(opt->name);
		for (; size < max; size++)
			fprintf(fp, " ");
		fprintf(fp, "  %s\n", *hlp);
	}
}

/*
 * Parse command line arguments
 */
static int
handle_cmdline(int *argc, char ***argv)
{
	for (;;) {
		int i;
		i = getopt_long(*argc, *argv, "c:s:t:vh", opts, NULL);
		if (i == -1) {
			break;
		}
		switch (i) {
		case 'c':
			if (!isdigit(optarg[0])) {
				usage(stderr);
				exit(EXIT_FAILURE);
			}
			max_events = atoi(optarg);
			break;
		case 's':
			socketfile = optarg;
			break;
		case 't':
			if (!isdigit(optarg[0])) {
				usage(stderr);
				exit(EXIT_FAILURE);
			}
			alarm(atoi(optarg));
			break;
		case 'v':
			printf(PACKAGE "-" VERSION "\n");
			exit(EXIT_SUCCESS);
		case 'h':
			usage(stdout);
			exit(EXIT_SUCCESS);
		default:
			usage(stderr);
			exit(EXIT_FAILURE);
			break;
		}
	}

	*argc -= optind;
	*argv += optind;

	return 0;
}

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
		buf = realloc(buf, buflen);
		if (!buf) {
			fprintf(stderr, "ERR: malloc(%d): %s\n",
				buflen, strerror(errno));
			return NULL;
		}
		memset(buf+i, 0, buflen-i);

		while (i < buflen) {
			r = read(fd, buf+i, 1);
			if (r < 0 && errno != EINTR) {
				/* we should do something with the data */
				fprintf(stderr, "ERR: read(): %s\n",
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
