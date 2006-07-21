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

#ifndef UTIL_H
#define UTIL_H

#include "ResourceManager.h"
#include "Pool.h"

namespace adchpp { 

/** Evaluates op(pair<T1, T2>.first, compareTo) */
template<class T1, class T2, class op = equal_to<T1> >
class CompareFirst {
public:
	CompareFirst(const T1& compareTo) : a(compareTo) { }
	bool operator()(const pair<T1, T2>& p) { return op()(p.first, a); }
private:
	CompareFirst& operator=(const CompareFirst&);
	const T1& a;
};

/** Evaluates op(pair<T1, T2>.second, compareTo) */
template<class T1, class T2, class op = equal_to<T2> >
class CompareSecond {
public:
	CompareSecond(const T2& compareTo) : a(compareTo) { }
	bool operator()(const pair<T1, T2>& p) { return op()(p.second, a); }
private:
	CompareSecond& operator=(const CompareSecond&);
	const T2& a;
};

struct DeleteFunction {
	template<typename T>
	void operator()(T* ptr) { delete ptr; }
};

/** A generic hash for pointers */
template<class T>
struct PointerHash {
#if _MSC_VER >= 1300 
	static const size_t bucket_size = 4; 
	static const size_t min_buckets = 8; 
#endif 
	size_t operator()(const T* a) const { return ((size_t)a)/sizeof(T); }
	bool operator()(const T* a, const T* b) { return a < b; }
};
template<>
struct PointerHash<void> {
	size_t operator()(const void* a) const { return ((size_t)a)>>2; }
};

/** 
 * Compares two values
 * @return -1 if v1 < v2, 0 if v1 == v2 and 1 if v1 > v2
 */
template<typename T1>
inline int compare(const T1& v1, const T1& v2) { return (v1 < v2) ? -1 : ((v1 == v2) ? 0 : 1); }

class Flags {
	public:
		typedef int MaskType;

		Flags() : flags(0) { }
		Flags(const Flags& rhs) : flags(rhs.flags) { }
		Flags(MaskType f) : flags(f) { }
		bool isSet(MaskType aFlag) const { return (flags & aFlag) == aFlag; }
		bool isAnySet(MaskType aFlag) const { return (flags & aFlag) != 0; }
		void setFlag(MaskType aFlag) { flags |= aFlag; }
		void unsetFlag(MaskType aFlag) { flags &= ~aFlag; }
		Flags& operator=(const Flags& rhs) { flags = rhs.flags; return *this; }
	private:
		MaskType flags;
};

template<typename T>
class AutoArray {
	typedef T* TPtr;
public:
	explicit AutoArray(TPtr t) : p(t) { }
	explicit AutoArray(size_t size) : p(new T[size]) { }
	~AutoArray() { delete[] p; }
	operator TPtr() { return p; }
	AutoArray& operator=(TPtr t) { delete[] p; p = t; return *this; }
private:
	AutoArray(const AutoArray&);
	AutoArray& operator=(const AutoArray&);

	TPtr p;
};

class Util  
{
public:
	struct Stats {
		int64_t totalUp;			///< Total bytes uploaded
		int64_t totalDown;			///< Total bytes downloaded
		u_int32_t startTime;		///< The time the hub was started
	};

	DLL static Stats stats;
	DLL static string emptyString;

	static void initialize();
	DLL static string getOsVersion();
	DLL static void decodeUrl(const string& aUrl, string& aServer, short& aPort, string& aFile);
	DLL static string formatTime(const string& msg, time_t t = time(NULL));
	
	static const string& getCfgPath() { return cfgPath; }
	static void setCfgPath(const string& path) { cfgPath = path; }
#ifdef _WIN32
	static string getAppPath() {
		string tmp(MAX_PATH + 1, '\0');
		tmp.resize(GetModuleFileName(NULL, &tmp[0], MAX_PATH));
		string::size_type i = tmp.rfind('\\');
		if(i != string::npos)
			tmp.erase(i+1);
		return tmp;
	}

	static string getAppName() {
		string tmp(MAX_PATH + 1, _T('\0'));
		tmp.resize(GetModuleFileName(NULL, &tmp[0], MAX_PATH));
		return tmp;
	}

#else // WIN32
	DLL static string appPath;
	DLL static string appName;

	static void setApp(const string app) {
		string::size_type i = app.rfind('/');
		if(i != string::npos) {
			appPath = app.substr(0, i+1);
			appName = app;
		}
	}
	static string getAppPath() {
		return appPath;
	}
	static string getAppName() {
		return appName;
	}
#endif // WIN32

	DLL static string translateError(int aError);
	
	static string toAcp(const wstring& wString) {
		if(wString.empty())
			return Util::emptyString;

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
	static const string& toAcp(const string& wString) {
		return wString;
	}
	static string& toAcp(string& wString) {
		return wString;
	}

	static wstring toUnicode(const string& aString) {
		wstring tmp(aString.length(), L'\0');
#ifdef _WIN32
		tmp.resize(MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, aString.c_str(), (int)aString.length(), &tmp[0], (int)tmp.length()));
#else
		tmp.resize(mbstowcs(&tmp[0], aString.c_str(), tmp.length()));
#endif
		return tmp;
	}
	static const wstring& toUnicode(const wstring& aString) {
		return aString;
	}
	static wstring& toUnicode(wstring& aString) {
		return aString;
	}

	static string formatBytes(const string& aString) { return formatBytes(toInt64(aString)); }

	DLL static string getShortTimeString();
	DLL static string getTimeString();
		
	DLL static string formatBytes(int64_t aBytes);

	static void tokenize(StringList& lst, const string& str, char sep, string::size_type j = 0) {
		string::size_type i = 0;
		while( (i=str.find_first_of(sep, j)) != string::npos ) {
			lst.push_back(str.substr(j, i-j));
			j = i + 1;
		}
		if(j <= str.size())
			lst.push_back(str.substr(j, str.size()-j));
	}

	static string formatSeconds(int64_t aSec) {
		char buf[64];
		sprintf(buf, "%01d:%02d:%02d:%02d", (int)(aSec / (24*60*60)), (int)((aSec / (60*60)) % 24), (int)((aSec / 60) % 60), (int)(aSec % 60));
		return buf;
	}
	
	static bool toBool(const string& aString) { return toBool(aString.c_str()); }
	static int toInt(const string& aString) { return toInt(aString.c_str()); }
	static double toDouble(const string& aString) { return toDouble(aString.c_str()); }
	static float toFloat(const string& aString) { return toFloat(aString.c_str()); }
	static int64_t toInt64(const string& aString) { return toInt64(aString.c_str()); }
	
	static bool toBool(const char* aString) { return toInt(aString) > 0; }
	static int toInt(const char* aString) { return ::atoi(aString); }
	static double toDouble(const char* aString) { return ::atof(aString); }
	static float toFloat(const char* aString) { return (float)::atof(aString); }
	static int64_t toInt64(const char* aString) {	
#ifdef _MSC_VER
		return _atoi64(aString);
#else
		return atoll(aString);
#endif
	}
	
	static string toString(short val) {
		char buf[8];
		sprintf(buf, "%d", (int)val);
		return buf;
	}	
	static string toString(unsigned short val) {
		char buf[8];
		sprintf(buf, "%u", (unsigned int)val);
		return buf;
	}	
	static string toString(int val) {
		char buf[16];
		sprintf(buf, "%d", val);
		return buf;
	}	
	static string toString(unsigned int val) {
		char buf[16];
		sprintf(buf, "%u", val);
		return buf;
	}	
	static string toString(long val) {
		char buf[32];
		sprintf(buf, "%ld", val);
		return buf;
	}	
	static string toString(unsigned long val) {
		char buf[32];
		sprintf(buf, "%lu", val);
		return buf;
	}
	static string toString(long long val) {
		char buf[32];
#ifdef _MSC_VER
		sprintf(buf, "%I64d", val);
#else
		sprintf(buf, "%lld", val);
#endif
		return buf;
	}
	static string toString(unsigned long long val) {
		char buf[32];
#ifdef _MSC_VER
		sprintf(buf, "%I64u", val);
#else
		sprintf(buf, "%llu", val);
#endif
		return buf;
	}
	
	static string toString(double val, int maxDec = 2) {
		char buf[32];
		sprintf(buf, "%.*f", maxDec, val);
		return buf;
	}

	static const string& toString(const string& aString) {
		return aString;
	}

	/** Avoid this! Use the one of a connected socket instead... */
	DLL static string getLocalIp();

	struct Clear {
		void operator()(ByteVector& x) { x.clear(); }
	};
	/** Pool of free buffers */
	static DLL Pool<ByteVector, Clear> freeBuf;

	static DLL u_int32_t rand();
	static u_int32_t rand(u_int32_t high) { return rand() % high; }
	static u_int32_t rand(u_int32_t low, u_int32_t high) { return rand(high-low) + low; }
	static double randd() { return ((double)rand()) / ((double)0xffffffff); }

private:
	DLL static string cfgPath;
};

}

#endif // UTIL_H
