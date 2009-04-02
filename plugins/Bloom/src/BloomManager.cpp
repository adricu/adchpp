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

#include "stdinc.h"
#include "BloomManager.h"

#include <adchpp/LogManager.h>
#include <adchpp/Client.h>
#include <adchpp/AdcCommand.h>
#include <adchpp/Util.h>

using namespace std;
using namespace std::tr1;
using namespace std::tr1::placeholders;
using namespace adchpp;

BloomManager* BloomManager::instance = 0;
const string BloomManager::className = "BloomManager";

// TODO Make configurable
const size_t h = 24;

BloomManager::BloomManager() : searches(0), tthSearches(0), stopped(0) {
	LOG(className, "Starting");
	ClientManager* cm = ClientManager::getInstance();
	receiveConn = manage(&cm->signalReceive(), std::tr1::bind(&BloomManager::onReceive, this, _1, _2, _3));
	sendConn = manage(&cm->signalSend(), std::tr1::bind(&BloomManager::onSend, this, _1, _2, _3));
	disconnectConn = manage(&cm->signalDisconnected(), std::tr1::bind(&BloomManager::onDisconnected, this, _1));
}

BloomManager::~BloomManager() {
	LOG(className, "Shutting down");
}

static const uint32_t FEATURE = AdcCommand::toFourCC("BLO0");

void BloomManager::onReceive(Entity& e, AdcCommand& cmd, bool& ok) {
	string tmp;

	Client* cc = dynamic_cast<Client*>(&e);
	if(!cc) {
		return;
	}

	Client& c = *cc;
	if(cmd.getCommand() == AdcCommand::CMD_INF && c.hasSupport(FEATURE)) {
		if(cmd.getParam("SF", 0, tmp)) {
			size_t n = adchpp::Util::toInt(tmp);
			if(n == 0) {
				return;
			}

			size_t k = HashBloom::get_k(n, h);
			size_t m = HashBloom::get_m(n, k);
			blooms.erase(c.getSID());

			pending[c.getSID()] = make_tuple(ByteVector(), m, k);

			AdcCommand get(AdcCommand::CMD_GET);
			get.addParam("blom");
			get.addParam("/");
			get.addParam("0");
			get.addParam(Util::toString(m/8));
			get.addParam("BK", Util::toString(k));
			get.addParam("BH", Util::toString(h));
			c.send(get);
		}
	} else if(cmd.getCommand() == AdcCommand::CMD_SND) {
		if(cmd.getParameters().size() < 4) {
			return;
		}
		if(cmd.getParam(0) != "blom") {
			return;
		}

		PendingMap::const_iterator i = pending.find(c.getSID());
		if(i == pending.end()) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_STATE, "Unexpected bloom filter update"));
			c.disconnect(Util::REASON_BAD_STATE);
			ok = false;
			return;
		}

		int64_t bytes = Util::toInt(cmd.getParam(3));

		if(bytes != static_cast<int64_t>(get<1>(i->second) / 8)) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid number of bytes"));
			c.disconnect(Util::REASON_PLUGIN);
			ok = false;
			pending.erase(c.getSID());
			return;
		}

		c.setDataMode(bind(&BloomManager::onData, this, _1, _2, _3), bytes);
		ok = false;
	} else if(cmd.getCommand() == AdcCommand::CMD_MSG && cmd.getParameters().size() >= 1) {
		if(cmd.getParam(0).compare(0, 6, "+stats") == 0) {
			string stats = "\nBloom filter statistics:";
			stats += "\nTotal outgoing searches: " + Util::toString(searches);
			stats += "\nOutgoing TTH searches: " + Util::toString(tthSearches) + " (" + Util::toString(tthSearches * 100. / searches) + "% of total)";
			stats += "\nStopped outgoing searches: " + Util::toString(stopped) + " (" + Util::toString(stopped * 100. / searches) + "% of total, " + Util::toString(stopped * 100. / tthSearches) + "% of TTH searches";
			int64_t bytes = getBytes();
			size_t clients = ClientManager::getInstance()->getEntities().size();
			stats += "\nClient support: " + Util::toString(blooms.size()) + "/" + Util::toString(clients) + " (" + Util::toString(blooms.size() * 100. / clients) + "%)";
			stats += "\nApproximate memory usage: " + Util::formatBytes(bytes) + ", " + Util::formatBytes(static_cast<double>(bytes) / clients) + "/client";
			c.send(AdcCommand(AdcCommand::CMD_MSG).addParam(stats));
			ok = false;
		}
	}
}

void BloomManager::onSend(Entity& c, const AdcCommand& cmd, bool& ok) {
	if(cmd.getCommand() == AdcCommand::CMD_SCH) {
		searches++;
		string tmp;
		if(cmd.getParam("TR", 0, tmp)) {
			tthSearches++;
			BloomMap::const_iterator i = blooms.find(c.getSID());
			if(i != blooms.end() && !i->second.match(TTHValue(tmp))) {
				// Stop it
				stopped++;
				dcdebug("Stopping search\n");
				ok = false;
			}
		}
	}
}
int64_t BloomManager::getBytes() const {
	int64_t bytes = 0;
	for(BloomMap::const_iterator i = blooms.begin(); i != blooms.end(); ++i) {
		bytes += i->second.size() / 8;
	}
	return bytes;
}

void BloomManager::onData(Entity& c, const uint8_t* data, size_t len) {
	PendingMap::iterator i = pending.find(c.getSID());
	if(i == pending.end()) {
		// Shouldn't happen
		return;
	}
	ByteVector& v = get<0>(i->second);
	v.insert(v.end(), data, data + len);

	if(v.size() == get<1>(i->second) / 8) {
		HashBloom& bloom = blooms[c.getSID()];
		bloom.reset(v, get<2>(i->second), h);
		pending.erase(i);
	}
}

void BloomManager::onDisconnected(Entity& c) {
	blooms.erase(c.getSID());
	pending.erase(c.getSID());
}
