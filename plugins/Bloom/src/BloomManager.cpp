/* 
 * Copyright (C) 2006-2007 Jacek Sieka, arnetheduck on gmail point com
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
#include "BloomManager.h"

#include <adchpp/LogManager.h>

using namespace std;
using namespace std::tr1::placeholders;

BloomManager* BloomManager::instance = 0;
const string BloomManager::className = "BloomManager";

BloomManager::BloomManager() {
	LOGDT(className, "Starting");
	ClientManager* cm = ClientManager::getInstance();
	receiveConn = manage(&cm->signalReceive(), std::tr1::bind(&BloomManager::onReceive, this, _1, _2, _3));
	disconnectConn = manage(&cm->signalDisconnected(), std::tr1::bind(&BloomManager::onDisconnected, this, _1));
}

BloomManager::~BloomManager() {
	LOGDT(className, "Shutting down");
}

static const std::string FEATURE = "BLOM";

void BloomManager::onReceive(Client& c, AdcCommand& cmd, int& override) {
	std::string tth;

	if(cmd.getCommand() == AdcCommand::CMD_INF && c.supports(FEATURE)) {
		AdcCommand get(AdcCommand::CMD_GET);
		get.addParam("blom");
		get.addParam("/");
		get.addParam("0");
		get.addParam("-1");
		c.send(get);
	} else if(cmd.getCommand() == AdcCommand::CMD_SND) {
		if(cmd.getParameters().size() < 4) {
			return;
		}
		if(cmd.getParam(0) != "blom") {
			return;
		}
		
		int64_t bytes = Util::toInt(cmd.getParam(4));
		
		c.setDataMode(std::tr1::bind(&BloomManager::onData, this, _1, _2, _3), bytes);
	} else if(cmd.getCommand() == AdcCommand::CMD_SCH && cmd.getParam("TH", 0, tth)) {
		
		BloomMap::const_iterator i = blooms.find(c.getCID());
		if(i != blooms.end() && i->second.match(TTHValue(tth))) {
			// Stop it
			override |= ClientManager::DONT_DISPATCH | ClientManager::DONT_SEND;
		}
	}
}

void BloomManager::onData(Client& c, const uint8_t* data, size_t len) {
	HashBloom& bloom = blooms[c.getCID()];
	for(size_t i = 0; i < len; ++i) {
		for(size_t j = 0; j < 8; ++j) {
			bloom.push_back(data[i] & 1 << j);
		}
	}
}

void BloomManager::onDisconnected(Client& c) {
	blooms.erase(c.getCID());
}

