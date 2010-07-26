/*
 *  connection_list.h - ACPI daemon connection list
 *
 *  Copyright (C) 2008, Ted Felix (www.tedfelix.com)
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
 *  Tabs at 4
 */

#ifndef CONNECTION_LIST_H__
#define CONNECTION_LIST_H__

#include <sys/select.h>

/*****************************************************************
 *  Connection List Public Members
 *****************************************************************/

struct connection
{
	/* file descriptor */
	int fd;

	/* process incoming data on the connection */
	void (* process)(int fd);
};

/* add a connection to the list */
extern void add_connection(struct connection *p);

/* delete a connection from the list */
extern void delete_connection(int fd);

/* find a connection in the list by file descriptor */
extern struct connection *find_connection(int fd);

/* get the number of connections in the list */
extern int get_number_of_connections();

/* get a specific connection by index from the list */
extern struct connection *get_connection(int i);

/* get an fd_set with all the fd's that have been added to the list */
extern const fd_set *get_fdset();

/* get the highest fd that was added to the list */
extern int get_highestfd();

#endif /* CONNECTION_LIST_H__ */
