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

#ifndef ADCHPP_ADC_COMMAND_H
#define ADCHPP_ADC_COMMAND_H

#include "common.h"
#include "Exception.h"
#include "Util.h"

namespace adchpp {

STANDARD_EXCEPTION(ParseException);

class AdcCommand {
public:
	template<uint32_t T>
	struct Type {
		enum { CMD = T };
	};

	enum Error {
		ERROR_GENERIC = 0,
		ERROR_HUB_GENERIC = 10,
		ERROR_HUB_FULL = 11,
		ERROR_HUB_DISABLED = 12,
		ERROR_LOGIN_GENERIC = 20,
		ERROR_NICK_INVALID = 21,
		ERROR_NICK_TAKEN = 22,
		ERROR_BAD_PASSWORD = 23,
		ERROR_CID_TAKEN = 24,
		ERROR_COMMAND_ACCESS = 25,
		ERROR_REGGED_ONLY = 26,
		ERROR_INVALID_PID = 27,
		ERROR_BANNED_GENERIC = 30,
		ERROR_PERM_BANNED = 31,
		ERROR_TEMP_BANNED = 32,
		ERROR_PROTOCOL_GENERIC = 40,
		ERROR_PROTOCOL_UNSUPPORTED = 41,
		ERROR_CONNECT_FAILED = 42,
		ERROR_INF_MISSING = 43,
		ERROR_BAD_STATE = 44,
		ERROR_FEATURE_MISSING = 45,
		ERROR_BAD_IP = 46,
		ERROR_TRANSFER_GENERIC = 50,
		ERROR_FILE_NOT_AVAILABLE = 51,
		ERROR_FILE_PART_NOT_AVAILABLE = 52,
		ERROR_SLOTS_FULL = 53
	};

	enum Severity {
		SEV_SUCCESS = 0,
		SEV_RECOVERABLE = 1,
		SEV_FATAL = 2
	};

	static const char TYPE_BROADCAST = 'B';
	static const char TYPE_CLIENT = 'C';
	static const char TYPE_DIRECT = 'D';
	static const char TYPE_ECHO = 'E';
	static const char TYPE_FEATURE = 'F';
	static const char TYPE_INFO = 'I';
	static const char TYPE_HUB = 'H';
	static const char TYPE_UDP = 'U';

	// Known commands...
#define C(n, a, b, c) static const uint32_t CMD_##n = (((uint32_t)a) | (((uint32_t)b)<<8) | (((uint32_t)c)<<16)); typedef Type<CMD_##n> n
	// Base commands
	C(SUP, 'S','U','P');
	C(STA, 'S','T','A');
	C(INF, 'I','N','F');
	C(MSG, 'M','S','G');
	C(SCH, 'S','C','H');
	C(RES, 'R','E','S');
	C(CTM, 'C','T','M');
	C(RCM, 'R','C','M');
	C(GPA, 'G','P','A');
	C(PAS, 'P','A','S');
	C(QUI, 'Q','U','I');
	C(GET, 'G','E','T');
	C(GFI, 'G','F','I');
	C(SND, 'S','N','D');
	C(SID, 'S','I','D');
	// Extensions
	C(CMD, 'C','M','D');
#undef C

	enum { HUB_SID = 0x41414141 };

	ADCHPP_DLL AdcCommand();
	ADCHPP_DLL explicit AdcCommand(Severity sev, Error err, const string& desc, char aType = TYPE_INFO);
	explicit AdcCommand(uint32_t cmd, char aType = TYPE_INFO, uint32_t aFrom = HUB_SID) : cmdInt(cmd), str(&tmp), from(aFrom), type(aType) { }
	explicit AdcCommand(const string& aLine) throw(ParseException) : cmdInt(0), str(&aLine), type(0) { parse(aLine); }
	AdcCommand(const AdcCommand& rhs) : parameters(rhs.parameters), cmdInt(rhs.cmdInt), str(&tmp), from(rhs.from), to(rhs.to), type(rhs.type) { }

	ADCHPP_DLL void parse(const string& aLine) throw(ParseException);
	uint32_t getCommand() const { return cmdInt; }
	char getType() const { return type; }

	StringList& getParameters() { return parameters; }
	const StringList& getParameters() const { return parameters; }

	ADCHPP_DLL const string& toString() const;
	void resetString() { tmp.clear(); str = &tmp; }

	AdcCommand& addParam(const string& name, const string& value) {
		parameters.push_back(name);
		parameters.back() += value;
		return *this;
	}
	AdcCommand& addParam(const string& param) {
		parameters.push_back(param);
		return *this;
	}
	const string& getParam(size_t n) const {
		return getParameters().size() > n ? getParameters()[n] : Util::emptyString;
	}

	/** Return a named parameter where the name is a two-letter code */
	ADCHPP_DLL bool getParam(const char* name, size_t start, string& ret) const;
	ADCHPP_DLL bool delParam(const char* name, size_t start);
	
	ADCHPP_DLL bool hasFlag(const char* name, size_t start) const;
	static uint16_t toCode(const char* x) { return *((uint16_t*)x); }

	bool operator==(uint32_t aCmd) const { return cmdInt == aCmd; }

	ADCHPP_DLL static void escape(const string& s, string& out);

	uint32_t getTo() const { return to; }
	void setTo(uint32_t aTo) { to = aTo; }
	uint32_t getFrom() const { return from; }
	void setFrom(uint32_t aFrom) { from = aFrom; }

	static uint32_t toSID(const string& aSID) { return *reinterpret_cast<const uint32_t*>(aSID.data()); }
	static string fromSID(const uint32_t aSID) { return string(reinterpret_cast<const char*>(&aSID), sizeof(aSID)); }
	static void appendSID(string& str, uint32_t aSID) { str.append(reinterpret_cast<const char*>(&aSID), sizeof(aSID)); }
private:
	AdcCommand& operator=(const AdcCommand&);

	StringList parameters;
	string features;
	union {
		char cmdChar[4];
		uint8_t cmd[4];
		uint32_t cmdInt;
	};
	const string* str;
	mutable string tmp;

	uint32_t from;
	uint32_t to;
	char type;
};

class Client;

template<class T>
class CommandHandler {
public:
	bool dispatch(Client& c, AdcCommand& cmd) {
#define C(n) case AdcCommand::CMD_##n: return ((T*)this)->handle(AdcCommand::n(), c, cmd); break;
		switch(cmd.getCommand()) {
			C(SUP);
			C(STA);
			C(INF);
			C(MSG);
			C(SCH);
			C(RES);
			C(CTM);
			C(RCM);
			C(GPA);
			C(PAS);
			C(QUI);
			C(GET);
			C(GFI);
			C(SND);
			C(SID);
			C(CMD);
			default: 
				dcdebug("Unknown ADC command: %.50s\n", cmd.toString().c_str());
				return true;
#undef C
		}
	}
};

}

#endif // ADC_COMMAND_H
