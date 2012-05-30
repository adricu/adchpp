/* 
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_ENCODER_H
#define ADCHPP_ENCODER_H

namespace adchpp {
	
class Encoder
{
public:
	ADCHPP_DLL static std::string& toBase32(const uint8_t* src, size_t len, std::string& tgt);
	static std::string toBase32(const uint8_t* src, size_t len) {
		std::string tmp;
		return toBase32(src, len, tmp);
	}
	ADCHPP_DLL static void fromBase32(const char* src, uint8_t* dst, size_t len);

	ADCHPP_DLL static const int8_t base32Table[256];
	ADCHPP_DLL static const char base32Alphabet[32];
private:
};

}

#endif // _ENCODER
