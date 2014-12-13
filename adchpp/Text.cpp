/*
 * Copyright (C) 2001-2014 Jacek Sieka, arnetheduck on gmail point com
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

#include "adchpp.h"

#include "Text.h"

#include "Util.h"

using namespace std;

namespace adchpp {

int Text::utf8ToWc(const char* str, wchar_t& c) {
	const auto c0 = static_cast<uint8_t>(str[0]);
	const auto bytes = 2 + !!(c0 & 0x20) + ((c0 & 0x30) == 0x30);

	if((c0 & 0xc0) == 0xc0) {                  // 11xx xxxx
		// # bytes of leading 1's; check for 0 next
		const auto check_bit = 1 << (7 - bytes);
		if (c0 & check_bit)
			return -1;

		c = (check_bit - 1) & c0;

		// 2-4 total, or 1-3 additional, bytes
		// Can't run off end of str so long as has sub-0x80-terminator
		for (auto i = 1; i < bytes; ++i) {
			const auto ci = static_cast<uint8_t>(str[i]);
			if ((ci & 0xc0) != 0x80)
				return -i;
			c = (c << 6) | (ci & 0x3f);
		}

		// Invalid UTF-8 code points
		if (c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) {
			// "REPLACEMENT CHARACTER": used to replace an incoming character
			// whose value is unknown or unrepresentable in Unicode
			c = 0xfffd;
			return -bytes;
		}

		return bytes;
	} else if ((c0 & 0x80) == 0) {             // 0xxx xxxx
		c = static_cast<unsigned char>(str[0]);
		return 1;
	} else {                                   // 10xx xxxx
		return -1;
	}
	dcassert(0);
}

void Text::wcToUtf8(wchar_t c, string& str) {
	// https://tools.ietf.org/html/rfc3629#section-3
	if(c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) {
		// Invalid UTF-8 code point
		// REPLACEMENT CHARACTER: http://www.fileformat.info/info/unicode/char/0fffd/index.htm
		wcToUtf8(0xfffd, str);
	} else if(c >= 0x10000) {
		str += (char)(0x80 | 0x40 | 0x20 | 0x10 | (c >> 18));
		str += (char)(0x80 | ((c >> 12) & 0x3f));
		str += (char)(0x80 | ((c >> 6) & 0x3f));
		str += (char)(0x80 | (c & 0x3f));
	} else if(c >= 0x0800) {
		str += (char)(0x80 | 0x40 | 0x20 | (c >> 12));
		str += (char)(0x80 | ((c >> 6) & 0x3f));
		str += (char)(0x80 | (c & 0x3f));
	} else if(c >= 0x0080) {
		str += (char)(0x80 | 0x40 | (c >> 6));
		str += (char)(0x80 | (c & 0x3f));
	} else {
		str += (char)c;
	}
}

const string& Text::acpToUtf8(const string& str, string& tmp) throw() {
	wstring wtmp;
	return wideToUtf8(acpToWide(str, wtmp), tmp);
}

const wstring& Text::acpToWide(const string& str, wstring& tmp) throw() {
	if(str.empty())
		return Util::emptyStringW;
#ifdef _WIN32
	int n = MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, str.c_str(), (int)str.length(), NULL, 0);
	if(n == 0) {
		return Util::emptyStringW;
	}

	tmp.resize(n);
	n = MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, str.c_str(), (int)str.length(), &tmp[0], n);
	if(n == 0) {
		return Util::emptyStringW;
	}
	return tmp;
#else
	size_t rv;
	wchar_t wc;
	const char *src = str.c_str();
	size_t n = str.length() + 1;

	tmp.clear();
	tmp.reserve(n);

	while(n > 0) {
		rv = mbrtowc(&wc, src, n, NULL);
		if(rv == 0 || rv == (size_t)-2) {
			break;
		} else if(rv == (size_t)-1) {
			tmp.push_back(L'_');
			++src;
			--n;
		} else {
			tmp.push_back(wc);
			src += rv;
			n -= rv;
		}
	}
	return tmp;
#endif
}

const string& Text::wideToUtf8(const wstring& str, string& tgt) throw() {
	if(str.empty()) {
		return Util::emptyString;
	}

	string::size_type n = str.length();
	tgt.clear();
	for(string::size_type i = 0; i < n; ++i) {
		wcToUtf8(str[i], tgt);
	}
	return tgt;
}

const string& Text::wideToAcp(const wstring& str, string& tmp) throw() {
	if(str.empty())
		return Util::emptyString;
#ifdef _WIN32
	int n = WideCharToMultiByte(CP_ACP, 0, str.c_str(), (int)str.length(), NULL, 0, NULL, NULL);
	if(n == 0) {
		return Util::emptyString;
	}

	tmp.resize(n);
	n = WideCharToMultiByte(CP_ACP, 0, str.c_str(), (int)str.length(), &tmp[0], n, NULL, NULL);
	if(n == 0) {
		return Util::emptyString;
	}
	return tmp;
#else
	const wchar_t* src = str.c_str();
	int n = wcsrtombs(NULL, &src, 0, NULL);
	if(n < 1) {
		return Util::emptyString;
	}
	src = str.c_str();
	tmp.resize(n);
	n = wcsrtombs(&tmp[0], &src, n, NULL);
	if(n < 1) {
		return Util::emptyString;
	}
	return tmp;
#endif
}

bool Text::validateUtf8(const string& str) throw() {
	string::size_type i = 0;
	while(i < str.length()) {
		wchar_t dummy = 0;
		int j = utf8ToWc(&str[i], dummy);
		if(j < 0)
			return false;
		i += j;
	}
	return true;
}

const string& Text::utf8ToAcp(const string& str, string& tmp) throw() {
	wstring wtmp;
	return wideToAcp(utf8ToWide(str, wtmp), tmp);
}

const wstring& Text::utf8ToWide(const string& str, wstring& tgt) throw() {
	tgt.reserve(str.length());
	string::size_type n = str.length();
	for(string::size_type i = 0; i < n; ) {
		wchar_t c = 0;
		int x = utf8ToWc(str.c_str() + i, c);
		if(x < 0) {
			tgt += '_';
			i += abs(x);
		} else {
			i += x;
			tgt += c;
		}
	}
	return tgt;
}

string Text::acpToUtf8(const string& str) throw() {
	string tmp;
	return acpToUtf8(str, tmp);
}

wstring Text::acpToWide(const string& str) throw() {
	wstring tmp;
	return acpToWide(str, tmp);
}

string Text::utf8ToAcp(const string& str) throw() {
	string tmp;
	return utf8ToAcp(str, tmp);
}

wstring Text::utf8ToWide(const string& str) throw() {
	wstring tmp;
	return utf8ToWide(str, tmp);
}

string Text::wideToAcp(const wstring& str) throw() {
	string tmp;
	return wideToAcp(str, tmp);
}

string Text::wideToUtf8(const wstring& str) throw() {
	string tmp;
	return wideToUtf8(str, tmp);
}

} // namespace adchpp
