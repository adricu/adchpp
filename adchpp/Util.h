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

#ifndef ADCHPP_UTIL_H
#define ADCHPP_UTIL_H

#include "Pool.h"

namespace adchpp {

/** Evaluates op(pair<T1, T2>.first, compareTo) */
template<class T1, class T2, class op = std::equal_to<T1> >
class CompareFirst {
public:
	CompareFirst(const T1& compareTo) : a(compareTo) { }
	bool operator()(const std::pair<T1, T2>& p) { return op()(p.first, a); }
private:
	CompareFirst& operator=(const CompareFirst&);
	const T1& a;
};

/** Evaluates op(pair<T1, T2>.second, compareTo) */
template<class T1, class T2, class op = std::equal_to<T2> >
class CompareSecond {
public:
	CompareSecond(const T2& compareTo) : a(compareTo) { }
	bool operator()(const std::pair<T1, T2>& p) { return op()(p.second, a); }
private:
	CompareSecond& operator=(const CompareSecond&);
	const T2& a;
};

struct DeleteFunction {
	template<typename T>
	void operator()(T* ptr) { delete ptr; }
};

/**
 * Compares two values
 * @return -1 if v1 < v2, 0 if v1 == v2 and 1 if v1 > v2
 */
template<typename T1>
inline int compare(const T1& v1, const T1& v2) { return (v1 < v2) ? -1 : ((v1 == v2) ? 0 : 1); }

class Flags {
	public:
		typedef size_t MaskType;

		Flags() : flags(0) { }
		Flags(const Flags& rhs) : flags(rhs.flags) { }
		Flags(MaskType f) : flags(f) { }
		MaskType getFlags() const { return flags; }
		bool isSet(MaskType aFlag) const { return (flags & aFlag) == aFlag; }
		bool isAnySet(MaskType aFlag) const { return (flags & aFlag) != 0; }
		void setFlag(MaskType aFlag) { flags |= aFlag; }
		void unsetFlag(MaskType aFlag) { flags &= ~aFlag; }
		Flags& operator=(const Flags& rhs) { flags = rhs.flags; return *this; }
	private:
		MaskType flags;
};

struct Stats {
	ADCHPP_DLL static size_t queueCalls;
	ADCHPP_DLL static int64_t queueBytes;
	ADCHPP_DLL static size_t sendCalls;
	ADCHPP_DLL static int64_t sendBytes;
	ADCHPP_DLL static int64_t recvCalls;
	ADCHPP_DLL static int64_t recvBytes;
	ADCHPP_DLL static time_t startTime;
};

class Util
{
public:
	enum Reason {
		REASON_BAD_STATE,
		REASON_CID_CHANGE,
		REASON_CID_TAKEN,
		REASON_FLOODING,
		REASON_HUB_FULL,
		REASON_INVALID_COMMAND_TYPE,
		REASON_INVALID_IP,
		REASON_INVALID_SID,
		REASON_LOGIN_TIMEOUT,
		REASON_MAX_COMMAND_SIZE,
		REASON_NICK_INVALID,
		REASON_NICK_TAKEN,
		REASON_NO_BASE_SUPPORT,
		REASON_NO_TIGR_SUPPORT,
		REASON_PID_MISSING,
		REASON_PID_CID_LENGTH,
		REASON_PID_CID_MISMATCH,
		REASON_PID_WITHOUT_CID,
		REASON_PLUGIN,
		REASON_WRITE_OVERFLOW,
		REASON_LAST,
	};

	ADCHPP_DLL static size_t reasons[REASON_LAST];

	ADCHPP_DLL static std::string emptyString;

	ADCHPP_DLL static void initialize(const std::string& configPath);
	ADCHPP_DLL static std::string getOsVersion();
	ADCHPP_DLL static void decodeUrl(const std::string& aUrl, std::string& aServer, short& aPort, std::string& aFile);
	ADCHPP_DLL static std::string formatTime(const std::string& msg, time_t t = time(NULL));

	static const std::string& getCfgPath() { return cfgPath; }
	static void setCfgPath(const std::string& path) { cfgPath = path; }

	ADCHPP_DLL static std::string getAppPath();
	ADCHPP_DLL static std::string getAppName();

#ifndef _WIN32
	ADCHPP_DLL static void setApp(const std::string& app);
	static std::string appPath;
	static std::string appName;

#endif

	ADCHPP_DLL static std::string translateError(int aError);

	ADCHPP_DLL static std::string toAcp(const std::wstring& wString);
	static const std::string& toAcp(const std::string& wString) { return wString; }
	static std::string& toAcp(std::string& wString) { return wString; }

	ADCHPP_DLL static std::wstring toUnicode(const std::string& aString);
	static const std::wstring& toUnicode(const std::wstring& aString) { return aString; }
	static std::wstring& toUnicode(std::wstring& aString) { return aString; }

	ADCHPP_DLL static bool validateUtf8(const std::string& str) throw();

	static std::string formatBytes(const std::string& aString) { return formatBytes(toInt64(aString)); }

	ADCHPP_DLL static std::string getShortTimeString();
	ADCHPP_DLL static std::string getTimeString();

	ADCHPP_DLL static std::string formatBytes(int64_t aBytes);

	ADCHPP_DLL static void tokenize(StringList& lst, const std::string& str, char sep, std::string::size_type j = 0);

	static std::string formatSeconds(int64_t aSec) {
		char buf[64];
		sprintf(buf, "%01d:%02d:%02d:%02d", (int)(aSec / (24*60*60)), (int)((aSec / (60*60)) % 24), (int)((aSec / 60) % 60), (int)(aSec % 60));
		return buf;
	}

	static bool toBool(const std::string& aString) { return toBool(aString.c_str()); }
	static int toInt(const std::string& aString) { return toInt(aString.c_str()); }
	static double toDouble(const std::string& aString) { return toDouble(aString.c_str()); }
	static float toFloat(const std::string& aString) { return toFloat(aString.c_str()); }
	static int64_t toInt64(const std::string& aString) { return toInt64(aString.c_str()); }

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

	static std::string toString(bool val) {
		return val ? "1" : "0";
	}

	static std::string toString(short val) {
		char buf[8];
		sprintf(buf, "%d", (int)val);
		return buf;
	}
	static std::string toString(unsigned short val) {
		char buf[8];
		sprintf(buf, "%u", (unsigned int)val);
		return buf;
	}
	static std::string toString(int val) {
		char buf[16];
		sprintf(buf, "%d", val);
		return buf;
	}
	static std::string toString(unsigned int val) {
		char buf[16];
		sprintf(buf, "%u", val);
		return buf;
	}
	static std::string toString(long val) {
		char buf[32];
		sprintf(buf, "%ld", val);
		return buf;
	}
	static std::string toString(unsigned long val) {
		char buf[32];
		sprintf(buf, "%lu", val);
		return buf;
	}
	static std::string toString(long long val) {
		char buf[32];
#if defined(_MSC_VER) || defined(__MINGW32__)
		sprintf(buf, "%I64d", val);
#else
		sprintf(buf, "%lld", val);
#endif
		return buf;
	}
	static std::string toString(unsigned long long val) {
		char buf[32];
#if defined(_MSC_VER) || defined(__MINGW32__)
		sprintf(buf, "%I64u", val);
#else
		sprintf(buf, "%llu", val);
#endif
		return buf;
	}

	static std::string toString(double val, int maxDec = 2) {
		char buf[32];
		sprintf(buf, "%.*f", maxDec, val);
		return buf;
	}

	static const std::string& toString(const std::string& aString) {
		return aString;
	}

	/** Avoid this! Use the one of a connected socket instead... */
	ADCHPP_DLL static std::string getLocalIp();

	ADCHPP_DLL static uint32_t rand();
	static uint32_t rand(uint32_t high) { return rand() % high; }
	static uint32_t rand(uint32_t low, uint32_t high) { return rand(high-low) + low; }
	static double randd() { return ((double)rand()) / ((double)0xffffffff); }

private:
	ADCHPP_DLL static std::string cfgPath;
};

}

#endif // UTIL_H
