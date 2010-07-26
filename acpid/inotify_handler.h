/*
 *  inotify_handler.h - inotify Handler for New Devices
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

#ifndef INOTIFY_HANDLER_H__
#define INOTIFY_HANDLER_H__

/* Set up an inotify watch on /dev/input. */
extern void open_inotify(void);

#endif /* INOTIFY_HANDLER_H__ */
