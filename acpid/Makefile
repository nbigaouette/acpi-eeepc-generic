# Makefile for ACPI daemon

# update these numbers for new releases
VERSION = 2.0.6

OPT = -O2

DESTDIR =
PREFIX = /usr

BINDIR = $(PREFIX)/bin
SBINDIR = $(PREFIX)/sbin
MANDIR = $(PREFIX)/share/man
DOCDIR = $(PREFIX)/share/doc/acpid

SBIN_PROGS = acpid
BIN_PROGS = acpi_listen
PROGS = $(SBIN_PROGS) $(BIN_PROGS)

acpid_SRCS = acpid.c acpi_ids.c connection_list.c event.c input_layer.c \
    inotify_handler.c libnetlink.c netlink.c proc.c sock.c ud_socket.c
acpid_OBJS = $(acpid_SRCS:.c=.o)

acpi_listen_SRCS = acpi_listen.c ud_socket.c
acpi_listen_OBJS = $(acpi_listen_SRCS:.c=.o)

all_SRCS = $(acpid_SRCS) $(acpi_listen_SRCS)

MAN8 = acpid.8 acpi_listen.8
MAN8GZ = $(MAN8:.8=.8.gz)

DOCS = COPYING Changelog README TESTPLAN TODO 

CFLAGS = -W -Wall -Werror -Wundef -Wshadow -D_GNU_SOURCE $(OPT) \
	-fno-strict-aliasing -g $(DEFS)
DEFS = -DVERSION="\"$(VERSION)\""

all: $(PROGS)

acpid: $(acpid_OBJS)

acpi_listen: $(acpi_listen_OBJS)

man: $(MAN8)
	for a in $^; do gzip -f -9 -c $$a > $$a.gz; done

install_docs:
	mkdir -p $(DESTDIR)/$(DOCDIR)
	for a in $(DOCS); do install -m 0644 $$a $(DESTDIR)/$(DOCDIR) ; done
	cp -a samples $(DESTDIR)/$(DOCDIR)

install: $(PROGS) man install_docs
	mkdir -p $(DESTDIR)/$(SBINDIR)
	mkdir -p $(DESTDIR)/$(BINDIR)
	install -m 0750 acpid $(DESTDIR)/$(SBINDIR)
	install -m 0755 acpi_listen $(DESTDIR)/$(BINDIR)
	mkdir -p $(DESTDIR)/$(MANDIR)/man8
	install -m 0644 $(MAN8GZ) $(DESTDIR)/$(MANDIR)/man8
# You might want to run mandb(8) after install in case your system uses it.

DISTTMP=/tmp
DISTNAME=acpid-$(VERSION)
FULLTMP = $(DISTTMP)/$(DISTNAME)
dist:
	rm -rf $(FULLTMP)
	mkdir -p $(FULLTMP)
	cp -a * $(FULLTMP)
	find $(FULLTMP) -type d -name CVS | xargs rm -rf
	make -C $(FULLTMP) clean
	make -C $(FULLTMP)/kacpimon clean
	rm -f $(FULLTMP)/cscope.out
	find $(FULLTMP) -name '*~' | xargs rm -f
	# Get rid of previous dist
	rm -f $(FULLTMP)/$(DISTNAME).tar.gz
	tar -C $(DISTTMP) -zcvf $(DISTNAME).tar.gz $(DISTNAME)
	rm -rf $(FULLTMP)

clean:
	$(RM) $(PROGS) $(MAN8GZ) *.o .depend

dep depend:
	@$(RM) .depend
	@$(MAKE) .depend

.depend: $(all_SRCS)
	@for f in $^; do \
		OBJ=$$(echo $$f | sed 's/\.cp*$$/.o/'); \
		$(CPP) $(PP_INCLUDES) -MM $$f -MT $$OBJ; \
	done > $@

# NOTE: 'sinclude' is "silent-include".  This suppresses a warning if
# .depend does not exist.  Since Makefile includes this file, and this
# file includes .depend, .depend is itself "a makefile" and Makefile is
# dependent on it.  Any makefile for which there is a rule (as above for
# .depend) will be evaluated before anything else.  If the rule executes
# and the makefile is updated, make will reload the original Makefile and
# start over.
#
# This means that the .depend rule will always be checked first.  If
# .depend gets rebuilt, then the dependencies we have already sincluded
# must have been stale.  Make starts over, the old dependencies are
# tossed, and the new dependencies are sincluded.
#
# So why use 'sinclude' instead of 'include'?  We want to ALWAYS make
# Makefile depend on .depend, even if .depend doesn't exist yet.  But we
# don't want that pesky warning.
sinclude .depend
