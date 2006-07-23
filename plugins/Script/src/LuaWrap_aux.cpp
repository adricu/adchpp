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

#include "stdinc.h"

#include "LuaWrap.h"
#include "LuaCommon.h"

#include <adchpp/AdcCommand.h>
#include <adchpp/TigerHash.h>

#include <luabind/return_reference_to_policy.hpp>
#include <luabind/out_value_policy.hpp>

using namespace luabind;

namespace {
size_t getParamCount(const AdcCommand* cmd) {
	return cmd->getParameters().size();
}

string getCommandString(const AdcCommand* cmd) {
	size_t c = cmd->getCommand();
	return string((char*)&c, 3);
}

struct LuaAdcCommand : public AdcCommand, public wrap_base {
	LuaAdcCommand() { }
	LuaAdcCommand(uint32_t a) : AdcCommand(a) { }
	LuaAdcCommand(const LuaAdcCommand& rhs) : AdcCommand(rhs), wrap_base(rhs) { }
	
	~LuaAdcCommand() throw() { }
};

void TigerHash_update(TigerHash* th, const string& str) {
	th->update(str.c_str(), str.size());
}
string TigerHash_finalize(TigerHash* th) {
	return string((const char*)th->finalize(), TigerHash::HASH_SIZE);
}

}

void LuaWrap::wrap_aux(lua_State* L) {
	module(L, module_name)
	[	
		class_<AdcCommand, LuaAdcCommand >("AdcCommand")
			.def(constructor<>())
			.def(constructor<uint32_t>())
			.def("addParam", (AdcCommand& (AdcCommand::*)(const string&))&AdcCommand::addParam, return_reference_to(_1))
			.def("addParam", (AdcCommand& (AdcCommand::*)(const string&, const string&))&AdcCommand::addParam, return_reference_to(_1))
			.def("delParam", &AdcCommand::delParam)
			.def("getCommand", &AdcCommand::getCommand)
			.def("getCommandString", &getCommandString)
			.def("getFrom", &AdcCommand::getFrom)
			.def("getParam", (const string&(AdcCommand::*)(size_t n)const)&AdcCommand::getParam)
			.def("getParam", (bool (AdcCommand::*)(const char*, size_t, string&)const)&AdcCommand::getParam, pure_out_value(_4))
			.def("getParamCount", &getParamCount)
			.def("getTo", &AdcCommand::getTo)
			.def("getType", &AdcCommand::getType)
			.def("hasFlag", &AdcCommand::hasFlag)
			.def("parse", &AdcCommand::parse)
			.def("resetString", &AdcCommand::resetString)
			.def("setFrom", &AdcCommand::setFrom)
			.def("setTo", &AdcCommand::setTo)
			.def("__tostring", &AdcCommand::toString)
			.enum_("Command")
			[
				value("CMD_CMD", AdcCommand::CMD_CMD),
				value("CMD_CTM", AdcCommand::CMD_CTM),
				value("CMD_DSC", AdcCommand::CMD_DSC),
				value("CMD_GET", AdcCommand::CMD_GET),
				value("CMD_GFI", AdcCommand::CMD_GFI),
				value("CMD_GPA", AdcCommand::CMD_GPA),
				value("CMD_INF", AdcCommand::CMD_INF),
				value("CMD_MSG", AdcCommand::CMD_MSG),
				value("CMD_PAS", AdcCommand::CMD_PAS),
				value("CMD_QUI", AdcCommand::CMD_QUI),
				value("CMD_RCM", AdcCommand::CMD_RCM),
				value("CMD_RES", AdcCommand::CMD_RES),
				value("CMD_SCH", AdcCommand::CMD_SCH),
				value("CMD_SID", AdcCommand::CMD_SID),
				value("CMD_SND", AdcCommand::CMD_SND),
				value("CMD_STA", AdcCommand::CMD_STA),
				value("CMD_SUP", AdcCommand::CMD_SUP)
			]
			.enum_("Type")
			[
				value("TYPE_BROADCAST", AdcCommand::TYPE_BROADCAST),
				value("TYPE_DIRECT", AdcCommand::TYPE_DIRECT),
				value("TYPE_FEATURE", AdcCommand::TYPE_FEATURE),
				value("TYPE_HUB", AdcCommand::TYPE_HUB),
				value("TYPE_INFO", AdcCommand::TYPE_INFO)
			]
			.enum_("Error")
			[
				value("ERROR_BAD_IP", AdcCommand::ERROR_BAD_IP),
				value("ERROR_BAD_PASSWORD", AdcCommand::ERROR_BAD_PASSWORD),
				value("ERROR_BAD_STATE", AdcCommand::ERROR_BAD_STATE),
				value("ERROR_BANNED_GENERIC", AdcCommand::ERROR_BANNED_GENERIC),
				value("ERROR_CID_TAKEN", AdcCommand::ERROR_CID_TAKEN),
				value("ERROR_COMMAND_ACCESS", AdcCommand::ERROR_COMMAND_ACCESS),
				value("ERROR_FEATURE_MISSING", AdcCommand::ERROR_FEATURE_MISSING),
				value("ERROR_FILE_NOT_AVAILABLE", AdcCommand::ERROR_FILE_NOT_AVAILABLE),
				value("ERROR_FILE_PART_NOT_AVAILABLE", AdcCommand::ERROR_FILE_PART_NOT_AVAILABLE),
				value("ERROR_GENERIC", AdcCommand::ERROR_GENERIC),
				value("ERROR_HUB_DISABLED", AdcCommand::ERROR_HUB_DISABLED),
				value("ERROR_HUB_FULL", AdcCommand::ERROR_HUB_FULL),
				value("ERROR_HUB_GENERIC", AdcCommand::ERROR_HUB_GENERIC),
				value("ERROR_INF_MISSING", AdcCommand::ERROR_INF_MISSING),
				value("ERROR_INVALID_PID", AdcCommand::ERROR_INVALID_PID),
				value("ERROR_LOGIN_GENERIC", AdcCommand::ERROR_LOGIN_GENERIC),
				value("ERROR_NICK_INVALID", AdcCommand::ERROR_NICK_INVALID),
				value("ERROR_NICK_TAKEN", AdcCommand::ERROR_NICK_TAKEN),
				value("ERROR_PERM_BANNED", AdcCommand::ERROR_PERM_BANNED),
				value("ERROR_PROTOCOL_GENERIC", AdcCommand::ERROR_PROTOCOL_GENERIC),
				value("ERROR_PROTOCOL_UNSUPPORTED", AdcCommand::ERROR_PROTOCOL_UNSUPPORTED),
				value("ERROR_REGGED_ONLY", AdcCommand::ERROR_REGGED_ONLY),
				value("ERROR_SLOTS_FULL", AdcCommand::ERROR_SLOTS_FULL),
				value("ERROR_TEMP_BANNED", AdcCommand::ERROR_TEMP_BANNED),
				value("ERROR_TRANSFER_GENERIC", AdcCommand::ERROR_TRANSFER_GENERIC)
			]
			.enum_("Severity")
			[
				value("SEV_FATAL", AdcCommand::SEV_FATAL),
				value("SEV_RECOVERABLE", AdcCommand::SEV_RECOVERABLE),
				value("SEV_SUCCESS", AdcCommand::SEV_SUCCESS)
			]
		,class_<TigerHash>("TigerHash")
			.def("update", &TigerHash_update)
			.def("finalize", &TigerHash_finalize)
			
		,def("getCfgPath", &Util::getCfgPath)
	];
}

