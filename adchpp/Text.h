/*
 * Copyright (C) 2001-2010 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_TEXT_H
#define ADCHPP_TEXT_H

namespace adchpp {

/**
 * Text handling routines for ADCH++. ADCH++ internally uses UTF-8 for
 * (almost) all string:s, hence all foreign text must be converted
 * appropriately...
 * acp - ANSI code page used by the system
 * wide - wide unicode string
 * utf8 - UTF-8 representation of the string
 * string - UTF-8 string (most of the time)
 * wstring - Wide string
 *
 * Taken from DC++.
 */
class Text {
	typedef std::string string;
	typedef std::wstring wstring;

public:
	static const string& acpToUtf8(const string& str, string& tmp) throw();
	ADCHPP_DLL static string acpToUtf8(const string& str) throw();

	static const wstring& acpToWide(const string& str, wstring& tmp) throw();
	ADCHPP_DLL static wstring acpToWide(const string& str) throw();

	static const string& utf8ToAcp(const string& str, string& tmp) throw();
	ADCHPP_DLL static string utf8ToAcp(const string& str) throw();

	static const wstring& utf8ToWide(const string& str, wstring& tmp) throw();
	ADCHPP_DLL static wstring utf8ToWide(const string& str) throw();

	static const string& wideToAcp(const wstring& str, string& tmp) throw();
	ADCHPP_DLL static string wideToAcp(const wstring& str) throw();

	static const string& wideToUtf8(const wstring& str, string& tmp) throw();
	ADCHPP_DLL static string wideToUtf8(const wstring& str) throw();

	ADCHPP_DLL static bool validateUtf8(const string& str) throw();

private:
	static int utf8ToWc(const char* str, wchar_t& c);
	static void wcToUtf8(wchar_t c, string& str);
};

} // namespace dcpp

#endif
