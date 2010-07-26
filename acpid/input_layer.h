/*
 *  input_layer.h - Kernel ACPI Event Input Layer Interface
 *
 *  Handles the details of getting kernel ACPI events from the input
 *  layer (/dev/input/event*).
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
 *  (tabs at 4)
 */

#ifndef INPUT_LAYER_H__
#define INPUT_LAYER_H__

/* Open each of the appropriate /dev/input/event* files for input. */
extern void open_input(void);

/* Open a single input layer device file for input. */
extern int open_inputfile(const char *filename);

#endif /* INPUT_LAYER_H__ */
