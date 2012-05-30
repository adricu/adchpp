/*
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
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

#include <random>

#include "Util.h"
#include "FastAlloc.h"

#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/utsname.h>
#include <ctype.h>

#endif

#include "TimeUtil.h"

namespace adchpp {

using namespace std;

#ifdef NDEBUG
FastMutex FastAllocBase::mtx;
#endif

#ifndef _WIN32
string Util::appName;
string Util::appPath;
#endif

string Util::emptyString;
wstring Util::emptyStringW;

/**
 * Decodes a URL the best it can...
 * Default ports:
 * http:// -> port 80
 * dchub:// -> port 411
 */
void Util::decodeUrl(const string& url, string& aServer, short& aPort, string& aFile) {
	// First, check for a protocol: xxxx://
	string::size_type i = 0, j, k;

	aServer.clear();
	aFile.clear();

	if( (j=url.find("://", i)) != string::npos) {
		// Protocol found
		string protocol = url.substr(0, j);
		i = j + 3;

		if(protocol == "http") {
			aPort = 80;
		} else if(protocol == "dchub") {
			aPort = 411;
		}
	}

	if( (j=url.find('/', i)) != string::npos) {
		// We have a filename...
		aFile = url.substr(j);
	}

	if( (k=url.find(':', i)) != string::npos) {
		// Port
		if(k < j)
			aPort = (short)Util::toInt(url.substr(k+1, j-k-1));
	} else {
		k = j;
	}

	// Only the server should be left now...
	aServer = url.substr(i, k-i);
}


void Util::tokenize(StringList& lst, const string& str, char sep, string::size_type j) {
	string::size_type i = 0;
	while( (i=str.find_first_of(sep, j)) != string::npos ) {
		lst.push_back(str.substr(j, i-j));
		j = i + 1;
	}
	if(j <= str.size())
		lst.push_back(str.substr(j, str.size()-j));
}

#ifdef _WIN32
string Util::getAppPath() {
	string tmp = getAppName();
	string::size_type i = tmp.rfind('\\');
	if(i != string::npos)
		tmp.erase(i+1);
	return tmp;
}

string Util::getAppName() {
	string tmp(MAX_PATH + 1, '\0');
	tmp.resize(::GetModuleFileNameA(NULL, &tmp[0], MAX_PATH));
	return tmp;
}

#else // WIN32

void Util::setApp(const string& app) {
	string::size_type i = app.rfind('/');
	if(i != string::npos) {
		appPath = app.substr(0, i+1);
		appName = app;
	}
}
string Util::getAppPath() {
	return appPath;
}
string Util::getAppName() {
	return appName;
}
#endif // WIN32

string Util::getLocalIp() {
	string tmp;

	char buf[256];
	gethostname(buf, 255);
	hostent* he = gethostbyname(buf);
	if(he == NULL || he->h_addr_list[0] == 0)
		return Util::emptyString;
	sockaddr_in dest;
	int i = 0;

	// We take the first ip as default, but if we can find a better one, use it instead...
	memcpy(&(dest.sin_addr), he->h_addr_list[i++], he->h_length);
	tmp = inet_ntoa(dest.sin_addr);
	if( strncmp(tmp.c_str(), "192", 3) == 0 ||
		strncmp(tmp.c_str(), "169", 3) == 0 ||
		strncmp(tmp.c_str(), "127", 3) == 0 ||
		strncmp(tmp.c_str(), "10", 2) == 0 ) {

		while(he->h_addr_list[i]) {
			memcpy(&(dest.sin_addr), he->h_addr_list[i], he->h_length);
			string tmp2 = inet_ntoa(dest.sin_addr);
			if(	strncmp(tmp2.c_str(), "192", 3) != 0 &&
				strncmp(tmp2.c_str(), "169", 3) != 0 &&
				strncmp(tmp2.c_str(), "127", 3) != 0 &&
				strncmp(tmp2.c_str(), "10", 2) != 0) {

				tmp = tmp2;
			}
			i++;
		}
	}
	return tmp;
}

string Util::formatBytes(int64_t aBytes) {
	char buf[64];
	if(aBytes < 1024) {
		sprintf(buf, "%d B", (int)(aBytes&0xffffffff));
	} else if(aBytes < 1024*1024) {
		sprintf(buf, "%.02f KiB", (double)aBytes/(1024.0));
	} else if(aBytes < 1024*1024*1024) {
		sprintf(buf, "%.02f MiB", (double)aBytes/(1024.0*1024.0));
	} else if(aBytes < (int64_t)1024*1024*1024*1024) {
		sprintf(buf, "%.02f GiB", (double)aBytes/(1024.0*1024.0*1024.0));
	} else {
		sprintf(buf, "%.02f TiB", (double)aBytes/(1024.0*1024.0*1024.0*1024.0));
	}

	return buf;
}

string Util::getShortTimeString() {
	char buf[8];
	time_t _tt;
	std::time(&_tt);
	tm* _tm = localtime(&_tt);
	strftime(buf, 8, "%H:%M", _tm);
	return buf;
}

string Util::getTimeString() {
	char buf[64];
	time_t _tt;
	std::time(&_tt);
	tm* _tm = localtime(&_tt);
	if(_tm == NULL) {
		strcpy(buf, "xx:xx:xx");
	} else {
		strftime(buf, 64, "%X", _tm);
	}
	return buf;
}

string Util::formatTime(const string& msg, time_t t /* = time(NULL) */) {
	size_t bufsize = msg.size() + 64;

	char* buf = new char[bufsize];

	while(!strftime(buf, bufsize-1, msg.c_str(), localtime(&t))) {
		delete buf;
		bufsize+=64;
		buf = new char[bufsize];
	}

	string result = buf;
	delete[] buf;
	return result;
}

string Util::translateError(int aError) {
#ifdef _WIN32
	LPVOID lpMsgBuf;
	::FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER |
		FORMAT_MESSAGE_FROM_SYSTEM |
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		aError,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,
		0,
		NULL
	);

#ifdef _UNICODE
	string tmp = Util::toAcp((LPCTSTR)lpMsgBuf);
#else
	string tmp = (LPCTSTR)lpMsgBuf;
#endif
		// Free the buffer.
	LocalFree( lpMsgBuf );
#else // WIN32
	string tmp = strerror(aError);
#endif // WIN32
	string::size_type i = 0;

	while( (i = tmp.find_first_of("\r\n", i)) != string::npos) {
		tmp.erase(i, 1);
	}
	return tmp;
}

string Util::getOsVersion() {
#ifdef _WIN32
	string os;

	OSVERSIONINFOEX ver;
	memset(&ver, 0, sizeof(OSVERSIONINFOEX));
	ver.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);

	if(!GetVersionEx((OSVERSIONINFO*)&ver)) {
		ver.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
		if(!GetVersionEx((OSVERSIONINFO*)&ver)) {
			os = "Windows (version unknown)";
		}
	}

	if(os.empty()) {
		if(ver.dwPlatformId != VER_PLATFORM_WIN32_NT) {
			os = "Win9x/ME/Junk";
		} else if(ver.dwMajorVersion == 4) {
			os = "WinNT4";
		} else if(ver.dwMajorVersion == 5) {
			if(ver.dwMinorVersion == 0) {
				os = "Win2000";
			} else if(ver.dwMinorVersion == 1) {
				os = "WinXP";
			} else if(ver.dwMinorVersion == 2) {
				os = "Win2003";
			} else {
				os = "WinUnknown";
			}

			if(ver.wProductType == VER_NT_WORKSTATION)
				os += " Pro";
			else if(ver.wProductType == VER_NT_SERVER)
				os += " Server";
			else if(ver.wProductType == VER_NT_DOMAIN_CONTROLLER)
				os += " DC";
		}

		if(ver.wServicePackMajor > 0) {
			os += " SP" + Util::toString(ver.wServicePackMajor);
		}
	}

	return os;

#else // WIN32
	utsname n;

	if(uname(&n) != 0) {
		return "unix (unknown version)";
	}

	return string(n.sysname) + " " + string(n.release) + " (" + string(n.machine) + ")";

#endif // WIN32
}

#ifdef __MINGW32__
// creating a random_device throws an exception in MinGW with GCC 4.6; simpler alternative...
uint32_t Util::rand() {
	static bool init = false;
	if(!init) {
		::srand(::time(0));
		init = true;
	}

	return ::rand();
}

#else
uint32_t Util::rand() {
	static std::random_device rd;
	static std::default_random_engine dre(rd());

	return dre();
}
#endif

bool Util::isPrivateIp(std::string const& ip) {
	struct in_addr addr;

	addr.s_addr = inet_addr(ip.c_str());

	if (addr.s_addr != INADDR_NONE) {
		unsigned long haddr = ntohl(addr.s_addr);
		return ((haddr & 0xff000000) == 0x0a000000 || // 10.0.0.0/8
				(haddr & 0xff000000) == 0x7f000000 || // 127.0.0.0/8
				(haddr & 0xfff00000) == 0xac100000 || // 172.16.0.0/12
				(haddr & 0xffff0000) == 0xc0a80000);  // 192.168.0.0/16
	}
	return false;
}
bool Util::validateCharset(std::string const& field, int p) {
	for(string::size_type i = 0; i < field.length(); ++i) {
		if((uint8_t) field[i] < p) {
			return false;
		}
	}
	return true;
}

 
}
