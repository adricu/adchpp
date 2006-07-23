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

#include "ScriptManager.h"

#include <adchpp/Client.h>
#include <adchpp/ClientManager.h>
#include <adchpp/LogManager.h>

#include <luabind/adopt_policy.hpp>

using namespace luabind;

namespace {

typedef pointer_wrapper<ClientManager> LuaClientManager;
	
LuaClientManager getCM() {
	return LuaClientManager(ClientManager::getInstance());
}

template<typename T, typename Signal>
struct LuaSignalHandler {
	LuaSignalHandler(const object& f_) : f(f_) { }
	virtual ~LuaSignalHandler() { }
	
	static T* create(const object& f) { 
		T* t = new T(f);
		t->connect();
		return t;
	}
	
	object f;
	ManagedConnection<Signal> c;
};

struct SignalConnectedHandler : public LuaSignalHandler<SignalConnectedHandler, ClientManager::SignalConnected> {
	SignalConnectedHandler(const object& f_) : LuaSignalHandler<SignalConnectedHandler, ClientManager::SignalConnected>(f_) { }
	
	void connect() { 
		c = ClientManager::getInstance()->signalConnected().connect(boost::ref(*this)); 
	}
	
	void operator()(Client& c) { 
		try {
			 f(&c);
		} catch(const luabind::error& e) {
			object error_msg(from_stack(e.state(), -1));
			LOGDT(ScriptManager::className, "Error in signalConnected: "  + object_cast<string>(error_msg));
		} catch(const exception& e) {
			LOGDT(ScriptManager::className, "Unexpected exception in signalConnected: " + string(e.what()) + ", " + string(typeid(e).name()));
		} catch(...) {
			LOGDT(ScriptManager::className, "Unknown error in signalConnected");
		}
	}
};

struct SignalReceiveHandler : public LuaSignalHandler<SignalReceiveHandler, ClientManager::SignalReceive> {
	SignalReceiveHandler(const object& f_) : LuaSignalHandler<SignalReceiveHandler, ClientManager::SignalReceive>(f_) { }
	
	void connect() { 
		c = ClientManager::getInstance()->signalReceive().connect(boost::ref(*this)); 
	}
	
	void operator()(Client& c, AdcCommand& cmd, int& override) { 
		try {
			override |= call_function<int>(f, &c, &cmd, override);
		} catch(const luabind::cast_failed&) {
			// Harmless...
			LOGDT(ScriptManager::className, "Invalid return value in signalReceive, forgot to return at end of function?");
		} catch(const luabind::error& e) {
			object error_msg(from_stack(e.state(), -1));
			LOGDT(ScriptManager::className, "Error in signalReceive: "  + object_cast<string>(error_msg));
		} catch(const exception& e) {
			LOGDT(ScriptManager::className, "Unexpected exception in signalDisconnected: " + string(e.what()) + ", " + string(typeid(e).name()));
		} catch(...) {
			LOGDT(ScriptManager::className, "Unknown error in signalReceive");
		}
	}
};

struct SignalDisconnectedHandler : public LuaSignalHandler<SignalDisconnectedHandler, ClientManager::SignalDisconnected> {
	SignalDisconnectedHandler(const object& f_) : LuaSignalHandler<SignalDisconnectedHandler, ClientManager::SignalDisconnected>(f_) { }
	
	void connect() { 
		c = ClientManager::getInstance()->signalDisconnected().connect(boost::ref(*this)); 
	}
	
	void operator()(Client& c) { 
		try {
			f(&c);
		} catch(const luabind::error& e) {
			object error_msg(from_stack(e.state(), -1));
			LOGDT(ScriptManager::className, "Error in signalDisconnected: "  + object_cast<string>(error_msg));
		} catch(const exception& e) {
			LOGDT(ScriptManager::className, "Unexpected exception in signalDisconnected: " + string(e.what()) + ", " + string(typeid(e).name()));
		} catch(...) {
			LOGDT(ScriptManager::className, "Unknown error in signalDisconnected");
		}
	}
};


string ClientManager_enterVerify(ClientManager*, Client& c, bool sendData) {
	vector<uint8_t> data = ClientManager::getInstance()->enterVerify(c, sendData);
	return string((const char*)&data[0], data.size());
}

bool ClientManager_verifyPassword(ClientManager*, Client& c, const string& password, const string& salt, const string& sentHash) {
	return ClientManager::getInstance()->verifyPassword(c, password, vector<uint8_t>((uint8_t*)&salt[0], (uint8_t*)(&salt[0] + salt.size())), sentHash);
}

Client* ClientManager_getClientByCID(ClientManager*, const std::string& cid) {
	uint32_t sid = ClientManager::getInstance()->getSID(CID(cid));
	if(sid == 0) {
		return 0;
	}
	return ClientManager::getInstance()->getClient(sid);
}

Client* ClientManager_getClientByNick(ClientManager*, const std::string& nick) {
	uint32_t sid = ClientManager::getInstance()->getSID(nick);
	if(sid == 0) {
		return 0;
	}
	return ClientManager::getInstance()->getClient(sid);
}

uint32_t ClientManager_getSIDByCID(const string& cid) {
	return ClientManager::getInstance()->getSID(CID(cid));
}

} // namespace

void LuaWrap::wrap_cm(lua_State* L) {
	module(L, module_name)
	[
		class_<SignalConnectedHandler>("SignalConnectedHandler")
		,class_<SignalReceiveHandler>("SignalReceiveHandler")
		,class_<ClientManager, LuaClientManager>("ClientManager")
			.enum_("override")
			[
				value("DONT_DISPATCH", ClientManager::DONT_DISPATCH)
				,value("DONT_SEND", ClientManager::DONT_SEND)
			]
			.def("addSupports", &ClientManager::addSupports)
			.def("enterIdentify", &ClientManager::enterIdentify)
			.def("enterVerify", &ClientManager_enterVerify)
			.def("enterNormal", &ClientManager::enterNormal)
			.def("getSIDByNick", (uint32_t (ClientManager::*)(const string&) const)&ClientManager::getSID)
			.def("getSIDByCID", &ClientManager_getSIDByCID)
			.def("getClientBySID", &ClientManager::getClient)
			.def("getClientByNick", &ClientManager_getClientByNick)
			.def("getClientByCID", &ClientManager_getClientByCID)
			.def("removeSupports", &ClientManager::removeSupports)
			.def("send", &ClientManager::send)
			.def("sendToAll", &ClientManager::sendToAll)
			.def("sendTo", &ClientManager::sendTo)
			.def("updateCache", &ClientManager::updateCache)
			.def("verifyCID", &ClientManager::verifyCID)
			.def("verifyINF", &ClientManager::verifyINF)
			.def("verifySUP", &ClientManager::verifySUP)
			.def("verifyIp", &ClientManager::verifyIp)
			.def("verifyNick", &ClientManager::verifyNick)
			.def("verifyPassword", &ClientManager_verifyPassword)
			.def("verifyUsers", &ClientManager::verifyUsers)
			
		,def("signalConnected", &SignalConnectedHandler::create, adopt(result))
		,def("signalReceive", &SignalReceiveHandler::create, adopt(result))
		,def("signalDisconnected", &SignalDisconnectedHandler::create, adopt(result))
		,def("getCM", &getCM)
	];
}

