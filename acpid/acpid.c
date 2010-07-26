/*
 *  acpid.c - ACPI daemon
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
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <getopt.h>
#include <stdarg.h>

#include "acpid.h"
#include "event.h"
#include "connection_list.h"
#include "proc.h"
#include "sock.h"
#include "input_layer.h"
#include "inotify_handler.h"
#include "netlink.h"

static int handle_cmdline(int *argc, char ***argv);
static void close_fds(void);
static int daemonize(void);
static void open_log(void);
static int std2null(void);
static int create_pidfile(void);
static void clean_exit(int sig);
static void reload_conf(int sig);

/* global debug level */
int acpid_debug;

/* do we log event info? */
int logevents;

const char *progname;
static const char *confdir = ACPID_CONFDIR;
static const char *lockfile = ACPID_LOCKFILE;
static int nosocket;
static int foreground;
static const char *pidfile = ACPID_PIDFILE;
static int netlink;

int
main(int argc, char **argv)
{
	/* learn who we really are */
	progname = (const char *)strrchr(argv[0], '/');
	progname = progname ? (progname + 1) : argv[0];

	/* handle the commandline  */
	handle_cmdline(&argc, &argv);

	/* close any extra file descriptors */
	close_fds();

	/* open the log */
	open_log();
	
	if (!netlink)
	{
		/* open the acpi event file in the proc fs */
		/* if the open fails, try netlink */
		if (open_proc())
			netlink = 1;
	}

	if (netlink)
	{
		/* open the input layer */
		open_input();

		/* watch for new input layer devices */
		open_inotify();

		/* open netlink */
		open_netlink();
	}

	/* open our socket */
	if (!nosocket) {
		open_sock();
	}

	/* if we're running in foreground, we don't daemonize */
	if (!foreground) {
		if (daemonize() < 0)
			exit(EXIT_FAILURE);
	}

	/* redirect standard files to /dev/null */
	if (std2null() < 0) {
		exit(EXIT_FAILURE);
	}
	
	acpid_log(LOG_INFO, "starting up with %s\n",
		netlink ? "netlink and the input layer" : "proc fs");

	/* trap key signals */
	signal(SIGHUP, reload_conf);
	signal(SIGINT, clean_exit);
	signal(SIGQUIT, clean_exit);
	signal(SIGTERM, clean_exit);
	signal(SIGPIPE, SIG_IGN);

	/* read in our configuration */
	if (acpid_read_conf(confdir)) {
		exit(EXIT_FAILURE);
	}

	/* create our pidfile */
	if (create_pidfile() < 0) {
		exit(EXIT_FAILURE);
	}

	acpid_log(LOG_INFO, "waiting for events: event logging is %s\n",
	    logevents ? "on" : "off");

	/* main loop */
	while (1)
	{
		fd_set readfds;
		int nready;
		int i;
		struct connection *p;

		/* it's going to get clobbered, so use a copy */
		readfds = *get_fdset();

		/* wait on data */
		nready = select(get_highestfd() + 1, &readfds, NULL, NULL, NULL);

		if (nready < 0  &&  errno == EINTR) {
			continue;
		} else if (nready < 0) {
			acpid_log(LOG_ERR, "select(): %s\n", strerror(errno));
			continue;
		}

		/* house keeping */
		acpid_close_dead_clients();

		/* for each connection */
		for (i = 0; i <= get_number_of_connections(); ++i)
		{
			int fd;

			p = get_connection(i);

			/* if this connection is invalid, bail */
			if (!p)
				break;

			/* get the file descriptor */
			fd = p->fd;

			/* if this file descriptor has data waiting */
			if (FD_ISSET(fd, &readfds))
			{
				/* delegate to this connection's process function */
				p->process(fd);
			}
		}
	}

	clean_exit_with_status(EXIT_SUCCESS);

	return 0;
}

/*
 * Parse command line arguments
 */
static int
handle_cmdline(int *argc, char ***argv)
{
	struct option opts[] = {
		{"confdir", 1, 0, 'c'},
		{"clientmax", 1, 0, 'C'},
		{"debug", 0, 0, 'd'},
		{"eventfile", 1, 0, 'e'},
		{"foreground", 0, 0, 'f'},
		{"logevents", 0, 0, 'l'},
		{"socketgroup", 1, 0, 'g'},
		{"socketmode", 1, 0, 'm'},
		{"socketfile", 1, 0, 's'},
		{"nosocket", 1, 0, 'S'},
		{"pidfile", 1, 0, 'p'},
		{"lockfile", 1, 0, 'L'},
		{"netlink", 0, 0, 'n'},
		{"version", 0, 0, 'v'},
		{"help", 0, 0, 'h'},
		{NULL, 0, 0, 0},
	};
	const char *opts_help[] = {
		"Set the configuration directory.",	/* confdir */
		"Set the limit on non-root socket connections.",/* clientmax */
		"Increase debugging level (implies -f).",/* debug */
		"Use the specified file for events.",	/* eventfile */
		"Run in the foreground.",		/* foreground */
		"Log all event activity.",		/* logevents */
		"Set the group on the socket file.",	/* socketgroup */
		"Set the permissions on the socket file.",/* socketmode */
		"Use the specified socket file.",	/* socketfile */
		"Do not listen on a UNIX socket (overrides -s).",/* nosocket */
		"Use the specified PID file.",		/* pidfile */
		"Use the specified lockfile to stop processing.", /* lockfile */
		"Force netlink/input layer mode. (overrides -e)", /* netlink */
		"Print version information.",		/* version */
		"Print this message.",			/* help */
	};
	struct option *opt;
	const char **hlp;
	int max, size;

	for (;;) {
		int i;
		i = getopt_long(*argc, *argv,
		    "c:C:de:flg:m:s:Sp:L:nvh", opts, NULL);
		if (i == -1) {
			break;
		}
		switch (i) {
		case 'c':
			confdir = optarg;
			break;
		case 'C':
			clientmax = strtol(optarg, NULL, 0);
			break;
		case 'd':
			foreground = 1;
			acpid_debug++;
			break;
		case 'e':
			eventfile = optarg;
			break;
		case 'f':
			foreground = 1;
			break;
		case 'l':
			logevents = 1;
			break;
		case 'g':
			socketgroup = optarg;
			break;
		case 'm':
			socketmode = strtol(optarg, NULL, 8);
			break;
		case 's':
			socketfile = optarg;
			break;
		case 'S':
			nosocket = 1;
			break;
		case 'p':
			pidfile = optarg;
			break;
		case 'L':
			lockfile = optarg;
			break;
		case 'n':
			netlink = 1;
			break;
		case 'v':
			printf(PACKAGE "-" VERSION "\n");
			exit(EXIT_SUCCESS);
		case 'h':
		default:
			fprintf(stderr, "Usage: %s [OPTIONS]\n", progname);
			max = 0;
			for (opt = opts; opt->name; opt++) {
				size = strlen(opt->name);
				if (size > max)
					max = size;
			}
			for (opt = opts, hlp = opts_help;
			     opt->name;
			     opt++, hlp++)
			{
				fprintf(stderr, "  -%c, --%s",
					opt->val, opt->name);
				size = strlen(opt->name);
				for (; size < max; size++)
					fprintf(stderr, " ");
				fprintf(stderr, "  %s\n", *hlp);
			}
			exit(EXIT_FAILURE);
			break;
		}
	}

	*argc -= optind;
	*argv += optind;

	return 0;
}

static void
close_fds(void)
{
	int fd, max;
	max = sysconf(_SC_OPEN_MAX);
	for (fd = 3; fd < max; fd++)
		close(fd);
}

static int
daemonize(void)
{
	pid_t pid, sid;

    /* already a daemon */
    if ( getppid() == 1 ) return 0;

	/* fork off the parent process */
	pid = fork();
	if (pid < 0) {
		acpid_log(LOG_ERR, "fork: %s\n", strerror(errno));
		return -1;
	}
	/* if we got a good PID, then we can exit the parent process */
	if (pid > 0) {
		exit(EXIT_SUCCESS);
	}

	/* at this point we are executing as the child process */

	/* change the umask to something predictable instead of inheriting */
	/* whatever from the parent */
	umask(0);

	/* create a new SID for the child process and */
	/* detach the process from the parent (normally a shell) */
	sid = setsid();
	if (sid < 0) {
		acpid_log(LOG_ERR, "setsid: %s\n", strerror(errno));
		return -1;
	}

    /* Change the current working directory.  This prevents the current
       directory from being locked; hence not being able to remove it. */
	if (chdir("/") < 0) {
		acpid_log(LOG_ERR, "chdir(\"/\"): %s\n", strerror(errno));
		return -1;
	}

	return 0;
}

static void
open_log(void)
{
	int log_opts;

	/* open the syslog */
	log_opts = LOG_CONS|LOG_NDELAY;
	if (acpid_debug) {
		log_opts |= LOG_PERROR;
	}
	openlog(PACKAGE, log_opts, LOG_DAEMON);
}

static int
std2null(void)
{
	int nullfd;

	/* open /dev/null */
	nullfd = open("/dev/null", O_RDWR);
	if (nullfd < 0) {
		acpid_log(LOG_ERR, "can't open /dev/null: %s\n", strerror(errno));
		return -1;
	}

	/* set up stdin, stdout, stderr to /dev/null */
	if (dup2(nullfd, STDIN_FILENO) != STDIN_FILENO) {
		acpid_log(LOG_ERR, "dup2() stdin: %s\n", strerror(errno));
		return -1;
	}
	if (!acpid_debug && dup2(nullfd, STDOUT_FILENO) != STDOUT_FILENO) {
		acpid_log(LOG_ERR, "dup2() stdout: %s\n", strerror(errno));
		return -1;
	}
	if (!acpid_debug && dup2(nullfd, STDERR_FILENO) != STDERR_FILENO) {
		acpid_log(LOG_ERR, "dup2() stderr: %s\n", strerror(errno));
		return -1;
	}

	close(nullfd);

	return 0;
}

static int
create_pidfile(void)
{
	int fd;

	/* JIC */
	unlink(pidfile);

	/* open the pidfile */
	fd = open(pidfile, O_WRONLY|O_CREAT|O_EXCL, 0644);
	if (fd >= 0) {
		FILE *f;

		/* write our pid to it */
		f = fdopen(fd, "w");
		if (f != NULL) {
			fprintf(f, "%d\n", getpid());
			fclose(f);
			/* leave the fd open */
			return 0;
		}
		close(fd);
	}

	/* something went wrong */
	acpid_log(LOG_ERR, "can't create pidfile %s: %s\n",
		    pidfile, strerror(errno));
	return -1;
}

void
clean_exit_with_status(int status)
{
	acpid_cleanup_rules(1);
	acpid_log(LOG_NOTICE, "exiting\n");
	unlink(pidfile);
	exit(status);
}

static void
clean_exit(int sig __attribute__((unused)))
{
	clean_exit_with_status(EXIT_SUCCESS);
}

static void
reload_conf(int sig __attribute__((unused)))
{
	acpid_log(LOG_NOTICE, "reloading configuration\n");
	acpid_cleanup_rules(0);
	acpid_read_conf(confdir);
}

int
#ifdef __GNUC__
__attribute__((format(printf, 2, 3)))
#endif
acpid_log(int level, const char *fmt, ...)
{
	va_list args;

	if (level == LOG_DEBUG) {
		/* if "-d" has been specified */
		if (acpid_debug) {
			/* send debug output to stderr */
			va_start(args, fmt);
			vfprintf(stderr, fmt, args);
			va_end(args);
		}
	} else {
		va_start(args, fmt);
		vsyslog(level, fmt, args);
		va_end(args);
	}

	return 0;
}

int
locked()
{
	struct stat trash;

	/* check for existence of a lockfile */
	return (stat(lockfile, &trash) == 0);
}

