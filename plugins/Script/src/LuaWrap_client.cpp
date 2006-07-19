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

#include <adchpp/Client.h>

using namespace luabind;

namespace {
std::string Client_getCID(Client* c) {
	return c->getCID().toBase32();	
}
}
void LuaWrap::wrap_client(lua_State* L) {
	module(L, module_name)
	[
		class_<Client>("Client")
			.def("disconnect", &Client::disconnect)
			.def("getField", &Client::getField)
			.def("getIp", &Client::getIp)
			.def("getCID", &Client_getCID)
			.def("getSID", &Client::getSID)
			.def("getState", &Client::getState)
			.def("isTcpActive", &Client::isTcpActive)
			.def("isUdpActive", &Client::isUdpActive)
			.def("resetChanged", &Client::resetChanged)
			.def("send", (void (Client::*)(const AdcCommand&))&Client::send)
			.def("send", (void (Client::*)(const string&))&Client::send)
			.def("send", (void (Client::*)(const char*, size_t))&Client::send)
			.def("setField", &Client::setField)
			.def("supports", &Client::supports)	
			.enum_("State")
			[
				value("STATE_PROTOCOL", Client::STATE_PROTOCOL)
				,value("STATE_IDENTIFY", Client::STATE_IDENTIFY)
				,value("STATE_VERIFY", Client::STATE_VERIFY)
				,value("STATE_NORMAL", Client::STATE_NORMAL)
				,value("STATE_DATA", Client::STATE_DATA)
			]
				
	];	
}
