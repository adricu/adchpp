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
#include <adchpp/Client.h>
#include <adchpp/AdcCommand.h>
#include <adchpp/Util.h>

using namespace std;
using namespace std::tr1::placeholders;
using namespace adchpp;

BloomManager* BloomManager::instance = 0;
const string BloomManager::className = "BloomManager";

BloomManager::BloomManager() {
	LOG(className, "Starting");
	ClientManager* cm = ClientManager::getInstance();
	receiveConn = manage(&cm->signalReceive(), std::tr1::bind(&BloomManager::onReceive, this, _1, _2, _3));
	disconnectConn = manage(&cm->signalDisconnected(), std::tr1::bind(&BloomManager::onDisconnected, this, _1));
}

BloomManager::~BloomManager() {
	LOG(className, "Shutting down");
}

static const std::string FEATURE = "BLO0";

void BloomManager::onReceive(Client& c, AdcCommand& cmd, int& override) {
	string tmp;

	if(cmd.getCommand() == AdcCommand::CMD_INF && c.supports(FEATURE)) {
		if(cmd.getParam("SF", 0, tmp)) {
			size_t n = adchpp::Util::toInt(tmp);
			if(n == 0) {
				return;
			}
			
			size_t k = HashBloom::get_k(n);
			size_t m = HashBloom::get_m(n, k);
			
			HashBloom& bloom = blooms[c.getCID()];
		
			bloom.reset(k);
			
			AdcCommand get(AdcCommand::CMD_GET);
			get.addParam("blom");
			get.addParam("/");
			get.addParam("0");
			get.addParam(Util::toString(m/8));
			get.addParam("BK", Util::toString(k));
			c.send(get);
		}
	} else if(cmd.getCommand() == AdcCommand::CMD_SND) {
		if(cmd.getParameters().size() < 4) {
			return;
		}
		if(cmd.getParam(0) != "blom") {
			return;
		}
		
		int64_t bytes = Util::toInt(cmd.getParam(3));
		
		c.setDataMode(std::tr1::bind(&BloomManager::onData, this, _1, _2, _3), bytes);
		override |= ClientManager::DONT_DISPATCH | ClientManager::DONT_SEND;
	} else if(cmd.getCommand() == AdcCommand::CMD_SCH && cmd.getParam("TR", 0, tmp)) {
		BloomMap::const_iterator i = blooms.find(c.getCID());
		if(i != blooms.end() && !i->second.match(TTHValue(tmp))) {
			// Stop it
			dcdebug("Stopping search\n");
			override |= ClientManager::DONT_DISPATCH | ClientManager::DONT_SEND;
		}
	}
}

void BloomManager::onData(Client& c, const uint8_t* data, size_t len) {
	HashBloom& bloom = blooms[c.getCID()];
	for(size_t i = 0; i < len; ++i) {
		for(size_t j = 0; j < 8; ++j) {
			bloom.push_back(data[i] & (1 << j));
		}
	}
}

void BloomManager::onDisconnected(Client& c) {
	blooms.erase(c.getCID());
}
