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

#include "adchpp.h"

#include "Util.h"
#include "FastAlloc.h"

#include <locale.h>
#ifndef _WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/utsname.h>
#include <ctype.h>

#endif

namespace adchpp {
	
#ifndef _DEBUG
FastMutex FastAllocBase::mtx;
#endif

#ifndef _WIN32
string Util::appName;
string Util::appPath;
#endif

Util::Stats Util::stats;
string Util::emptyString;
string Util::cfgPath;
size_t Util::reasons[REASON_LAST];

Pool<ByteVector, Util::Clear> Util::freeBuf;

static void sgenrand(unsigned long seed);

void Util::initialize(const string& configPath) {
	setlocale(LC_ALL, "");
	sgenrand((unsigned long)time(NULL));
	
	setCfgPath(configPath);
}

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
string Util::toAcp(const wstring& wString) {
	if(wString.empty())
		return emptyString;

	string str;

#ifdef _WIN32
	str.resize(WideCharToMultiByte(CP_ACP, 0, wString.c_str(), (int)wString.length(), NULL, 0, NULL, NULL));
	WideCharToMultiByte(CP_ACP, 0, wString.c_str(), (int)wString.length(), &str[0], (int)str.length(), NULL, NULL);
#else
	str.resize(wcstombs(NULL, wString.c_str(), 0)+ 1);
	wcstombs(&str[0], wString.c_str(), str.size());
#endif
	while(!str.empty() && str[str.length() - 1] == 0)
		str.erase(str.length()-1);
	return str;
}

wstring Util::toUnicode(const string& aString) {
	wstring tmp(aString.length(), L'\0');
#ifdef _WIN32
	tmp.resize(MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, aString.c_str(), (int)aString.length(), &tmp[0], (int)tmp.length()));
#else
	tmp.resize(mbstowcs(&tmp[0], aString.c_str(), tmp.length()));
#endif
	return tmp;
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
	string tmp(MAX_PATH + 1, '\0');
	tmp.resize(GetModuleFileName(NULL, &tmp[0], MAX_PATH));
	string::size_type i = tmp.rfind('\\');
	if(i != string::npos)
		tmp.erase(i+1);
	return tmp;
}

string Util::getAppName() {
	string tmp(MAX_PATH + 1, _T('\0'));
	tmp.resize(GetModuleFileName(NULL, &tmp[0], MAX_PATH));
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
		sprintf(buf, "%d %s", (int)(aBytes&0xffffffff), CSTRING(B));
	} else if(aBytes < 1024*1024) {
		sprintf(buf, "%.02f %s", (double)aBytes/(1024.0), CSTRING(KB));
	} else if(aBytes < 1024*1024*1024) {
		sprintf(buf, "%.02f %s", (double)aBytes/(1024.0*1024.0), CSTRING(MB));
	} else if(aBytes < (int64_t)1024*1024*1024*1024) {
		sprintf(buf, "%.02f %s", (double)aBytes/(1024.0*1024.0*1024.0), CSTRING(GB));
	} else {
		sprintf(buf, "%.02f %s", (double)aBytes/(1024.0*1024.0*1024.0*1024.0), CSTRING(TB));
	}
	
	return buf;
}

string Util::getShortTimeString() {
	char buf[8];
	time_t _tt;
	time(&_tt);
	tm* _tm = localtime(&_tt);
	strftime(buf, 8, "%H:%M", _tm);
	return buf;
}

string Util::getTimeString() {
	char buf[64];
	time_t _tt;
	time(&_tt);
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

/* Below is a high-speed random number generator with much
better granularity than the CRT one in msvc...(no, I didn't
write it...see copyright) */ 
/* Copyright (C) 1997 Makoto Matsumoto and Takuji Nishimura.
Any feedback is very welcome. For any question, comments,       
see http://www.math.keio.ac.jp/matumoto/emt.html or email       
matumoto@math.keio.ac.jp */       
/* Period parameters */  
#define N 624
#define M 397
#define MATRIX_A 0x9908b0df   /* constant vector a */
#define UPPER_MASK 0x80000000 /* most significant w-r bits */
#define LOWER_MASK 0x7fffffff /* least significant r bits */

/* Tempering parameters */   
#define TEMPERING_MASK_B 0x9d2c5680
#define TEMPERING_MASK_C 0xefc60000
#define TEMPERING_SHIFT_U(y)  (y >> 11)
#define TEMPERING_SHIFT_S(y)  (y << 7)
#define TEMPERING_SHIFT_T(y)  (y << 15)
#define TEMPERING_SHIFT_L(y)  (y >> 18)

static unsigned long mt[N]; /* the array for the state vector  */
static int mti=N+1; /* mti==N+1 means mt[N] is not initialized */

/* initializing the array with a NONZERO seed */
static void sgenrand(unsigned long seed) {
	/* setting initial seeds to mt[N] using         */
	/* the generator Line 25 of Table 1 in          */
	/* [KNUTH 1981, The Art of Computer Programming */
	/*    Vol. 2 (2nd Ed.), pp102]                  */
	mt[0]= seed & 0xffffffff;
	for (mti=1; mti<N; mti++)
		mt[mti] = (69069 * mt[mti-1]) & 0xffffffff;
}

uint32_t Util::rand() {
	unsigned long y;
	static unsigned long mag01[2]={0x0, MATRIX_A};
	/* mag01[x] = x * MATRIX_A  for x=0,1 */

	if (mti >= N) { /* generate N words at one time */
		int kk;

		if (mti == N+1)   /* if sgenrand() has not been called, */
			sgenrand(4357); /* a default initial seed is used   */

		for (kk=0;kk<N-M;kk++) {
			y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
			mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag01[y & 0x1];
		}
		for (;kk<N-1;kk++) {
			y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
			mt[kk] = mt[kk+(M-N)] ^ (y >> 1) ^ mag01[y & 0x1];
		}
		y = (mt[N-1]&UPPER_MASK)|(mt[0]&LOWER_MASK);
		mt[N-1] = mt[M-1] ^ (y >> 1) ^ mag01[y & 0x1];

		mti = 0;
	}

	y = mt[mti++];
	y ^= TEMPERING_SHIFT_U(y);
	y ^= TEMPERING_SHIFT_S(y) & TEMPERING_MASK_B;
	y ^= TEMPERING_SHIFT_T(y) & TEMPERING_MASK_C;
	y ^= TEMPERING_SHIFT_L(y);

	return y; 
}

}
