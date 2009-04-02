/* 
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef ADCHPP_VERSION_H
#define ADCHPP_VERSION_H

namespace adchpp {
	ADCHPP_DLL extern std::string appName;
	ADCHPP_DLL extern std::string versionString;
	ADCHPP_DLL extern float versionFloat;
}

// This should be updated whenever the plugin API changes
#define PLUGINVERSION 1

#endif // VERSION_H
