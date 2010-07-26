/*
 *  event.c - ACPI daemon event handler
 *
 *  Copyright (C) 2000 Andrew Henroid
 *  Copyright (C) 2001 Sun Microsystems (thockin@sun.com)
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
#include <sys/wait.h>
#include <sys/poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <ctype.h>
#include <regex.h>
#include <signal.h>

#include "acpid.h"
#include "sock.h"
#include "ud_socket.h"

/*
 * What is a rule?  It's polymorphic, pretty much.
 */
#define RULE_REGEX_FLAGS (REG_EXTENDED | REG_ICASE | REG_NOSUB | REG_NEWLINE)
struct rule {
	enum {
		RULE_NONE = 0,
		RULE_CMD,
		RULE_CLIENT,
	} type;
	char *origin;
	regex_t *event;
	union {
		char *cmd;
		int fd;
	} action;
	struct rule *next;
	struct rule *prev;
};
struct rule_list {
	struct rule *head;
	struct rule *tail;
};
static struct rule_list cmd_list;
static struct rule_list client_list;

/* rule routines */
static void enlist_rule(struct rule_list *list, struct rule *r);
static void delist_rule(struct rule_list *list, struct rule *r);
static struct rule *new_rule(void);
static void free_rule(struct rule *r);

/* other helper routines */
static void lock_rules(void);
static void unlock_rules(void);
static sigset_t *signals_handled(void);
static struct rule *parse_file(const char *file);
static struct rule *parse_client(int client);
static int do_cmd_rule(struct rule *r, const char *event);
static int do_client_rule(struct rule *r, const char *event);
static int safe_write(int fd, const char *buf, int len);
static char *parse_cmd(const char *cmd, const char *event);
static int check_escapes(const char *str);

/*
 * read in all the configuration files
 */
int
acpid_read_conf(const char *confdir)
{
	DIR *dir;
	struct dirent *dirent;
	char *file = NULL;
	int nrules = 0;
	regex_t preg;
	int rc = 0;

	lock_rules();

	dir = opendir(confdir);
	if (!dir) {
		acpid_log(LOG_ERR, "opendir(%s): %s\n",
			confdir, strerror(errno));
		unlock_rules();
		return -1;
	}

	/* Compile the regular expression.  This is based on run-parts(8). */
	rc = regcomp(&preg, "^[a-zA-Z0-9_-]+$", RULE_REGEX_FLAGS);
	if (rc) {
		acpid_log(LOG_ERR, "regcomp(): %d\n", rc);
		unlock_rules();
		return -1;
	}

	/* scan all the files */
	while ((dirent = readdir(dir))) {
		int len;
		struct rule *r;
		struct stat stat_buf;

		len = strlen(dirent->d_name);

		/* skip any files that don't match the run-parts convention */
		if (regexec(&preg, dirent->d_name, 0, NULL, 0) != 0) {
			acpid_log(LOG_INFO, "skipping conf file %s/%s\n", 
				confdir, dirent->d_name);
			continue;
		}

		/* Compute the length of the full path name adding one for */
		/* the slash and one more for the NULL. */
		len += strlen(confdir) + 2;

		file = malloc(len);
		if (!file) {
			acpid_log(LOG_ERR, "malloc(): %s\n", strerror(errno));
			unlock_rules();
			return -1;
		}
		snprintf(file, len, "%s/%s", confdir, dirent->d_name);

		/* allow only regular files and symlinks to files */
		if (stat(file, &stat_buf) != 0) {
			acpid_log(LOG_ERR, "stat(%s): %s\n", file,
				strerror(errno));
			free(file);
			continue; /* keep trying the rest of the files */
		}
		if (!S_ISREG(stat_buf.st_mode)) {
			acpid_log(LOG_INFO, "skipping non-file %s\n", file);
			free(file);
			continue; /* skip non-regular files */
		}

		r = parse_file(file);
		if (r) {
			enlist_rule(&cmd_list, r);
			nrules++;
		}
		free(file);
	}
	closedir(dir);
	unlock_rules();

	acpid_log(LOG_INFO, "%d rule%s loaded\n",
	    nrules, (nrules == 1)?"":"s");

	return 0;
}

/*
 * cleanup all rules
 */
int
acpid_cleanup_rules(int do_detach)
{
	struct rule *p;
	struct rule *next;

	lock_rules();

	if (acpid_debug >= 3) {
		acpid_log(LOG_DEBUG, "cleaning up rules\n");
	}

	if (do_detach) {
		/* tell our clients to buzz off */
		p = client_list.head;
		while (p) {
			next = p->next;
			delist_rule(&client_list, p);
			close(p->action.fd);
			free_rule(p);
			p = next;
		}
	}

	/* clear out our conf rules */
	p = cmd_list.head;
	while (p) {
		next = p->next;
		delist_rule(&cmd_list, p);
		free_rule(p);
		p = next;
	}

	unlock_rules();

	return 0;
}

static struct rule *
parse_file(const char *file)
{
	FILE *fp;
	char buf[512];
	int line = 0;
	struct rule *r;

	acpid_log(LOG_DEBUG, "parsing conf file %s\n", file);

	fp = fopen(file, "r");
	if (!fp) {
		acpid_log(LOG_ERR, "fopen(%s): %s\n", file, strerror(errno));
		return NULL;
	}

	/* make a new rule */
	r = new_rule();
	if (!r) {
		fclose(fp);
		return NULL;
	}
	r->type = RULE_CMD;
	r->origin = strdup(file);
	if (!r->origin) {
		acpid_log(LOG_ERR, "strdup(): %s\n", strerror(errno));
		free_rule(r);
		fclose(fp);
		return NULL;
	}

	/* read each line */
	while (!feof(fp) && !ferror(fp)) {
		char *p = buf;
		char key[64];
		char val[512];
		int n;

		line++;
		memset(key, 0, sizeof(key));
		memset(val, 0, sizeof(val));

		if (fgets(buf, sizeof(buf)-1, fp) == NULL) {
			continue;
		}

		/* skip leading whitespace */
		while (*p && isspace((int)*p)) {
			p++;
		}
		/* blank lines and comments get ignored */
		if (!*p || *p == '#') {
			continue;
		}

		/* quick parse */
		n = sscanf(p, "%63[^=\n]=%255[^\n]", key, val);
		if (n != 2) {
			acpid_log(LOG_WARNING, "can't parse %s at line %d\n",
			    file, line);
			continue;
		}
		if (acpid_debug >= 3) {
			acpid_log(LOG_DEBUG, "    key=\"%s\" val=\"%s\"\n",
			    key, val);
		}
		/* handle the parsed line */
		if (!strcasecmp(key, "event")) {
			int rv;
			r->event = malloc(sizeof(regex_t));
			if (!r->event) {
				acpid_log(LOG_ERR, "malloc(): %s\n",
					strerror(errno));
				free_rule(r);
				fclose(fp);
				return NULL;
			}
			rv = regcomp(r->event, val, RULE_REGEX_FLAGS);
			if (rv) {
				char rbuf[128];
				regerror(rv, r->event, rbuf, sizeof(rbuf));
				acpid_log(LOG_ERR, "regcomp(): %s\n", rbuf);
				free_rule(r);
				fclose(fp);
				return NULL;
			}
		} else if (!strcasecmp(key, "action")) {
			if (check_escapes(val) < 0) {
				acpid_log(LOG_ERR, "can't load file %s\n",
				    file);
				free_rule(r);
				fclose(fp);
				return NULL;
			}
			r->action.cmd = strdup(val);
			if (!r->action.cmd) {
				acpid_log(LOG_ERR, "strdup(): %s\n",
					strerror(errno));
				free_rule(r);
				fclose(fp);
				return NULL;
			}
		} else {
			acpid_log(LOG_WARNING,
			    "unknown option '%s' in %s at line %d\n",
			    key, file, line);
			continue;
		}
	}
	if (!r->event || !r->action.cmd) {
		acpid_log(LOG_INFO, "skipping incomplete file %s\n", file);
		free_rule(r);
		fclose(fp);
		return NULL;
	}
	fclose(fp);

	return r;
}

int
acpid_add_client(int clifd, const char *origin)
{
	struct rule *r;
	int nrules = 0;

	acpid_log(LOG_NOTICE, "client connected from %s\n", origin);

	r = parse_client(clifd);
	if (r) {
		r->origin = strdup(origin);
		enlist_rule(&client_list, r);
		nrules++;
	}

	acpid_log(LOG_INFO, "%d client rule%s loaded\n",
	    nrules, (nrules == 1)?"":"s");

	return 0;
}

static struct rule *
parse_client(int client)
{
	struct rule *r;
	int rv;

	/* make a new rule */
	r = new_rule();
	if (!r) {
		return NULL;
	}
	r->type = RULE_CLIENT;
	r->action.fd = client;
	r->event = malloc(sizeof(regex_t));
	if (!r->event) {
		acpid_log(LOG_ERR, "malloc(): %s\n", strerror(errno));
		free_rule(r);
		return NULL;
	}
	rv = regcomp(r->event, ".*", RULE_REGEX_FLAGS);
	if (rv) {
		char buf[128];
		regerror(rv, r->event, buf, sizeof(buf));
		acpid_log(LOG_ERR, "regcomp(): %s\n", buf);
		free_rule(r);
		return NULL;
	}

	return r;
}

/*
 * a few rule methods
 */

static void
enlist_rule(struct rule_list *list, struct rule *r)
{
	r->next = r->prev = NULL;
	if (!list->head) {
		list->head = list->tail = r;
	} else {
		list->tail->next = r;
		r->prev = list->tail;
		list->tail = r;
	}
}

static void
delist_rule(struct rule_list *list, struct rule *r)
{
	if (r->next) {
		r->next->prev = r->prev;
	} else {
		list->tail = r->prev;
	}

	if (r->prev) {
		r->prev->next = r->next;
	} else {
		list->head = r->next;;
	}

	r->next = r->prev = NULL;
}

static struct rule *
new_rule(void)
{
	struct rule *r;

	r = malloc(sizeof(*r));
	if (!r) {
		acpid_log(LOG_ERR, "malloc(): %s\n", strerror(errno));
		return NULL;
	}

	r->type = RULE_NONE;
	r->origin = NULL;
	r->event = NULL;
	r->action.cmd = NULL;
	r->prev = r->next = NULL;

	return r;
}

/* I hope you delisted the rule before you free() it */
static void
free_rule(struct rule *r)
{
	if (r->type == RULE_CMD) {
		if (r->action.cmd) {
			free(r->action.cmd);
		}
	}

	if (r->origin) {
		free(r->origin);
	}
	if (r->event) {
		regfree(r->event);
		free(r->event);
	}

	free(r);
}

static int
client_is_dead(int fd)
{
	struct pollfd pfd;
	int r;

	/* check the fd to see if it is dead */
	pfd.fd = fd;
	pfd.events = POLLERR | POLLHUP;
	r = poll(&pfd, 1, 0);

	if (r < 0) {
		acpid_log(LOG_ERR, "poll(): %s\n", strerror(errno));
		return 0;
	}

	return pfd.revents;
}

void
acpid_close_dead_clients(void)
{
	struct rule *p;

	lock_rules();

	/* scan our client list */
	p = client_list.head;
	while (p) {
		struct rule *next = p->next;
		if (client_is_dead(p->action.fd)) {
			struct ucred cred;
			/* closed */
			acpid_log(LOG_NOTICE,
			    "client %s has disconnected\n", p->origin);
			delist_rule(&client_list, p);
			ud_get_peercred(p->action.fd, &cred);
			if (cred.uid != 0) {
				non_root_clients--;
			}
			close(p->action.fd);
			free_rule(p);
		}
		p = next;
	}

	unlock_rules();
}

/*
 * the main hook for propogating events
 */
int
acpid_handle_event(const char *event)
{
	struct rule *p;
	int nrules = 0;
	struct rule_list *ar[] = { &client_list, &cmd_list, NULL };
	struct rule_list **lp;

	/* make an event be atomic wrt known signals */
	lock_rules();

	/* scan each rule list for any rules that care about this event */
	for (lp = ar; *lp; lp++) {
		struct rule_list *l = *lp;
		p = l->head;
		while (p) {
			/* the list can change underneath us */
			struct rule *pnext = p->next;
			if (!regexec(p->event, event, 0, NULL, 0)) {
				/* a match! */
				if (logevents) {
					acpid_log(LOG_INFO,
					    "rule from %s matched\n",
					    p->origin);
				}
				nrules++;
				if (p->type == RULE_CMD) {
					do_cmd_rule(p, event);
				} else if (p->type == RULE_CLIENT) {
					do_client_rule(p, event);
				} else {
					acpid_log(LOG_WARNING,
					    "unknown rule type: %d\n",
					    p->type);
				}
			} else {
				if (acpid_debug >= 3 && logevents) {
					acpid_log(LOG_INFO,
					    "rule from %s did not match\n",
					    p->origin);
				}
			}
			p = pnext;
		}
	}

	unlock_rules();

	if (logevents) {
		acpid_log(LOG_INFO, "%d total rule%s matched\n",
			nrules, (nrules == 1)?"":"s");
	}

	return 0;
}

/* helper functions to block signals while iterating */
static sigset_t *
signals_handled(void)
{
	static sigset_t set;

	sigemptyset(&set);
	sigaddset(&set, SIGHUP);
	sigaddset(&set, SIGTERM);
	sigaddset(&set, SIGQUIT);
	sigaddset(&set, SIGINT);

	return &set;
}

static void
lock_rules(void)
{
	if (acpid_debug >= 4) {
		acpid_log(LOG_DEBUG, "blocking signals for rule lock\n");
	}
	sigprocmask(SIG_BLOCK, signals_handled(), NULL);
}

static void
unlock_rules(void)
{
	if (acpid_debug >= 4) {
		acpid_log(LOG_DEBUG, "unblocking signals for rule lock\n");
	}
	sigprocmask(SIG_UNBLOCK, signals_handled(), NULL);
}

/*
 * the meat of the rules
 */

static int
do_cmd_rule(struct rule *rule, const char *event)
{
	pid_t pid;
	int status;
	const char *action;

	pid = fork();
	switch (pid) {
	case -1:
		acpid_log(LOG_ERR, "fork(): %s\n", strerror(errno));
		return -1;
	case 0: /* child */
		/* parse the commandline, doing any substitutions needed */
		action = parse_cmd(rule->action.cmd, event);
		if (logevents) {
			acpid_log(LOG_INFO,
			    "executing action \"%s\"\n", action);
		}

		/* reset signals */
		signal(SIGHUP, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGINT, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGPIPE, SIG_DFL);
		sigprocmask(SIG_UNBLOCK, signals_handled(), NULL);

		if (acpid_debug && logevents) {
			fprintf(stdout, "BEGIN HANDLER MESSAGES\n");
		}
		execl("/bin/sh", "/bin/sh", "-c", action, NULL);
		/* should not get here */
		acpid_log(LOG_ERR, "execl(): %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}

	/* parent */
	waitpid(pid, &status, 0);
	if (acpid_debug && logevents) {
		fprintf(stdout, "END HANDLER MESSAGES\n");
	}

	if (logevents) {
		if (WIFEXITED(status)) {
			acpid_log(LOG_INFO, "action exited with status %d\n",
			    WEXITSTATUS(status));
		} else if (WIFSIGNALED(status)) {
			acpid_log(LOG_INFO, "action exited on signal %d\n",
			    WTERMSIG(status));
		} else {
			acpid_log(LOG_INFO, "action exited with status %d\n",
			    status);
		}
	}

	return 0;
}

static int
do_client_rule(struct rule *rule, const char *event)
{
	int r;
	int client = rule->action.fd;

	if (logevents) {
		acpid_log(LOG_INFO, "notifying client %s\n", rule->origin);
	}

	r = safe_write(client, event, strlen(event));
	if (r < 0 && errno == EPIPE) {
		struct ucred cred;
		/* closed */
		acpid_log(LOG_NOTICE,
		    "client %s has disconnected\n", rule->origin);
		delist_rule(&client_list, rule);
		ud_get_peercred(rule->action.fd, &cred);
		if (cred.uid != 0) {
			non_root_clients--;
		}
		close(rule->action.fd);
		free_rule(rule);
		return -1;
	}
	safe_write(client, "\n", 1);

	return 0;
}

#define NTRIES 100
static int
safe_write(int fd, const char *buf, int len)
{
	int r;
	int ttl = 0;
	int ntries = NTRIES;

	do {
		r = write(fd, buf+ttl, len-ttl);
		if (r < 0) {
			if (errno != EAGAIN && errno != EINTR) {
				/* a legit error */
				return r;
			}
			ntries--;
		} else if (r > 0) {
			/* as long as we make forward progress, reset ntries */
			ntries = NTRIES;
			ttl += r;
		}
	} while (ttl < len && ntries);

	if (!ntries) {
		/* crap */
		if (acpid_debug >= 2) {
			acpid_log(LOG_ERR, "uh-oh! safe_write() timed out\n");
		}
		return r;
	}

	return ttl;
}

static char *
parse_cmd(const char *cmd, const char *event)
{
	static char buf[4096];
	size_t i;
	const char *p;

	p = cmd;
	i = 0;

	memset(buf, 0, sizeof(buf));
	while (i < (sizeof(buf)-1)) {
		if (*p == '%') {
			p++;
			if (*p == 'e') {
				/* handle an event expansion */
				size_t size = sizeof(buf) - i;
				size = snprintf(buf+i, size, "%s", event);
				i += size;
				p++;
				continue;
			}
		}
		if (!*p) {
			break;
		}
		buf[i++] = *p++;
	}
	if (acpid_debug >= 2) {
		acpid_log(LOG_DEBUG, "expanded \"%s\" -> \"%s\"\n", cmd, buf);
	}

	return buf;
}

static int
check_escapes(const char *str)
{
	const char *p;
	int r = 0;

	p = str;
	while (*p) {
		/* found an escape */
		if (*p == '%') {
			p++;
			if (!*p) {
				acpid_log(LOG_WARNING,
				    "invalid escape at EOL\n");
				return -1;
			} else if (*p != '%' && *p != 'e') {
				acpid_log(LOG_WARNING,
				    "invalid escape \"%%%c\"\n", *p);
				r = -1;
			}
		}
		p++;
	}
	return r;
}
