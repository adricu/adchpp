/* 
 * Copyright (C) 2006 Jacek Sieka, arnetheduck on gmail point com
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

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#define APPNAME "ADCH++"
#define VERSIONSTRING "2.0"
#define VERSIONFLOAT 2.0
#define PLUGINVERSIONSTRING "2.0"
#define PLUGINVERSIONFLOAT 2.0

#ifdef _DEBUG
#define BUILDSTRING "Debug"
#else
#define BUILDSTRING "Release"
#endif

#define FULLVERSIONSTRING APPNAME " v" VERSIONSTRING "-" BUILDSTRING " (Plugin API v" PLUGINVERSIONSTRING ")"

#endif // VERSION_H
