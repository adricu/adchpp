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

#ifndef ADCHPP_ADC_COMMAND_H
#define ADCHPP_ADC_COMMAND_H

#include "common.h"
#include "Exception.h"
#include "Util.h"
#include "Buffer.h"

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
		ERROR_NO_HUB_HASH = 47,
		ERROR_TRANSFER_GENERIC = 50,
		ERROR_FILE_NOT_AVAILABLE = 51,
		ERROR_FILE_PART_NOT_AVAILABLE = 52,
		ERROR_SLOTS_FULL = 53,
		ERROR_NO_CLIENT_HASH = 54
	};

	enum Severity {
		SEV_SUCCESS = 0,
		SEV_RECOVERABLE = 1,
		SEV_FATAL = 2
	};

	enum Priority {
		PRIORITY_NORMAL,		///< Default priority, command will be sent out normally
		PRIORITY_LOW,			///< Low priority, command will only be sent if connection isn't saturated
		PRIORITY_IGNORE			///< Ignore, command will not be put in send queue
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

	static const uint32_t HUB_SID = 0xffffffff;

	static uint32_t toSID(const std::string& aSID) { return *reinterpret_cast<const uint32_t*>(aSID.data()); }
	static std::string fromSID(const uint32_t aSID) { return std::string(reinterpret_cast<const char*>(&aSID), sizeof(aSID)); }
	static void appendSID(std::string& str, uint32_t aSID) { str.append(reinterpret_cast<const char*>(&aSID), sizeof(aSID)); }

	static uint32_t toCMD(uint8_t a, uint8_t b, uint8_t c) { return (((uint32_t)a) | (((uint32_t)b)<<8) | (((uint32_t)c)<<16)); }
	static uint32_t toCMD(const char* str) { return toCMD(str[0], str[1], str[2]); }

	static uint16_t toField(const char* x) { return *((uint16_t*)x); }
	static std::string fromField(const uint16_t aField) { return std::string(reinterpret_cast<const char*>(&aField), sizeof(aField)); }

	static uint32_t toFourCC(const char* x) { return *reinterpret_cast<const uint32_t*>(x); }
	static std::string fromFourCC(uint32_t x) { return std::string(reinterpret_cast<const char*>(&x), sizeof(x)); }

	ADCHPP_DLL AdcCommand();
	ADCHPP_DLL explicit AdcCommand(Severity sev, Error err, const std::string& desc, char aType = TYPE_INFO);
	explicit AdcCommand(uint32_t cmd, char aType = TYPE_INFO, uint32_t aFrom = HUB_SID) : cmdInt(cmd), priority(PRIORITY_NORMAL), from(aFrom), type(aType) { }
	explicit AdcCommand(const std::string& aLine) throw(ParseException) : cmdInt(0), priority(PRIORITY_NORMAL), type(0) { parse(aLine); }
	explicit AdcCommand(const BufferPtr& buffer_) throw(ParseException) : buffer(buffer_), cmdInt(0), priority(PRIORITY_NORMAL), type(0) { parse((const char*)buffer->data(), buffer->size()); }
	AdcCommand(const AdcCommand& rhs) : parameters(rhs.parameters), cmdInt(rhs.cmdInt), priority(PRIORITY_NORMAL), from(rhs.from), to(rhs.to), type(rhs.type) { }

	void parse(const std::string& str) throw(ParseException) { parse(str.data(), str.size()); }
	ADCHPP_DLL void parse(const char* buf, size_t len) throw(ParseException);
	uint32_t getCommand() const { return cmdInt; }
	char getType() const { return type; }
	std::string getFourCC() const { std::string tmp(4, 0); tmp[0] = type; tmp[1] = cmd[0]; tmp[2] = cmd[1]; tmp[3] = cmd[2]; return tmp; }
	StringList& getParameters() { return parameters; }
	const StringList& getParameters() const { return parameters; }
	ADCHPP_DLL std::string toString() const;

	AdcCommand& addParam(const std::string& param) {
		parameters.push_back(param);
		return *this;
	}

	AdcCommand& addParam(const std::string& name, const std::string& value) {
		return addParam(name + value);
	}

	const std::string& getParam(size_t n) const {
		return getParameters().size() > n ? getParameters()[n] : Util::emptyString;
	}

	void resetBuffer() { buffer = BufferPtr(); }

	const std::string& getFeatures() const { return features; }

	/** Return a named parameter where the name is a two-letter code */
	ADCHPP_DLL bool getParam(const char* name, size_t start, std::string& ret) const;
	ADCHPP_DLL bool delParam(const char* name, size_t start);

	ADCHPP_DLL bool hasFlag(const char* name, size_t start) const;

	bool operator==(uint32_t aCmd) const { return cmdInt == aCmd; }

	ADCHPP_DLL static void escape(const std::string& s, std::string& out);

	ADCHPP_DLL const BufferPtr& getBuffer() const;

	uint32_t getTo() const { return to; }
	void setTo(uint32_t aTo) { to = aTo; }
	uint32_t getFrom() const { return from; }
	void setFrom(uint32_t aFrom) { from = aFrom; }

	Priority getPriority() const { return priority; }
	void setPriority(Priority priority_) { priority = priority_; }

private:
	AdcCommand& operator=(const AdcCommand&);

	StringList parameters;
	std::string features;

	mutable BufferPtr buffer;

	union {
		char cmdChar[4];
		uint8_t cmd[4];
		uint32_t cmdInt;
	};

	Priority priority;
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
