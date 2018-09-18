/*
 * Copyright (C) 2006-2018 Jacek Sieka, arnetheduck on gmail point com
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

#include "File.h"

namespace adchpp {

using namespace std;

const char compileTime[] = __DATE__ " " __TIME__;

//#ifdef _DEBUG
void logAssert(const char* file, int line, const char* exp) {
	try {
		//File f(Util::getCfgPath() + _T("exceptioninfo.txt"), File::WRITE, File::OPEN | File::CREATE);
		//f.setEndPos(0);

		//f.write(string(file) + "(" + Util::toString(line) + "): " + string(exp) + "\r\n");
	} catch (const FileException& e) {
		dcdebug("logAssert: %s\n", e.getError().c_str());
	}
}
//#endif // _DEBUG

}
