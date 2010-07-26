/*
 *$Id: ud_socket.h,v 1.3 2009/04/22 18:22:28 thockin Exp $
 */

#ifndef UD_SOCKET_H__
#define UD_SOCKET_H__

#include <sys/socket.h>
#include <sys/un.h>

int ud_create_socket(const char *name);
int ud_accept(int sock, struct ucred *cred);
int ud_connect(const char *name);
int ud_get_peercred(int fd, struct ucred *cred);

#endif
