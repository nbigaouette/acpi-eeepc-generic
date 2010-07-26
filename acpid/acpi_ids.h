/*
 *  acpi_ids.h - ACPI Netlink Group and Family IDs
 *
 *  Copyright (C) 2008 Ted Felix (www.tedfelix.com)
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

#ifndef ACPI_IDS_H__
#define ACPI_IDS_H__

/* returns the netlink family ID for ACPI event messages */
extern __u16 acpi_ids_getfamily();

/* returns the netlink multicast group ID for ACPI event messages */
extern __u32 acpi_ids_getgroup();

#endif /* ACPI_IDS_H__ */
