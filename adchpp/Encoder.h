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

#ifndef _ENCODER
#define _ENCODER

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

class Encoder
{
public:
	DLL static string& toBase32(const u_int8_t* src, size_t len, string& tgt);
	static string toBase32(const u_int8_t* src, size_t len) {
		string tmp;
		return toBase32(src, len, tmp);
	}
	DLL static void fromBase32(const char* src, u_int8_t* dst, size_t len);

	DLL static const int8_t base32Table[256];
	DLL static const char base32Alphabet[32];
private:
};

#endif // _ENCODER
