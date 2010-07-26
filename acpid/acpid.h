/*
 *  acpid.h - ACPI daemon
 *
 *  Copyright (C) 1999-2000 Andrew Henroid
 *  Copyright (C) 2001 Sun Microsystems
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

#ifndef ACPID_H__
#define ACPID_H__

#include <syslog.h>

#define ACPI_PROCDIR 		"/proc/acpi"
#define ACPID_EVENTFILE		ACPI_PROCDIR "/event"
#define ACPID_CONFDIR		"/etc/acpi/events"
#define ACPID_SOCKETFILE	"/var/run/acpid.socket"
#define ACPID_SOCKETMODE	0666
#define ACPID_CLIENTMAX		256
#define ACPID_PIDFILE		"/var/run/acpid.pid"
#define ACPID_LOCKFILE		"/var/lock/acpid"
#define ACPID_MAX_ERRS		5

/* ??? make these changeable by commandline option? */
#define ACPID_INPUTLAYERDIR   "/dev/input"
#define ACPID_INPUTLAYERFILES ACPID_INPUTLAYERDIR "/event*"

#define PACKAGE 		"acpid"

/*
 * acpid.c
 */
extern int acpid_debug;
extern int logevents;
extern const char *progname;

extern int acpid_log(int level, const char *fmt, ...);

extern int locked();

extern void clean_exit_with_status(int status);

#endif /* ACPID_H__ */
