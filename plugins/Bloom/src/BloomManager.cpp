/*
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
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
#include <adchpp/PluginManager.h>

using namespace std;
using namespace std::placeholders;
using namespace adchpp;

BloomManager* BloomManager::instance = 0;
const string BloomManager::className = "BloomManager";

// TODO Make configurable
const size_t h = 24;

struct PendingItem {
	PendingItem(size_t m_, size_t k_) : m(m_), k(k_) { buffer.reserve(m/8); }
	ByteVector buffer;
	size_t m;
	size_t k;
};

BloomManager::BloomManager() : searches(0), tthSearches(0), stopped(0) {
	LOG(className, "Starting");
	ClientManager* cm = ClientManager::getInstance();
	receiveConn = manage(&cm->signalReceive(), std::bind(&BloomManager::onReceive, this, _1, _2, _3));
	sendConn = manage(&cm->signalSend(), std::bind(&BloomManager::onSend, this, _1, _2, _3));

	PluginManager* pm = PluginManager::getInstance();
	bloomHandle = pm->registerPluginData(&PluginData::simpleDataDeleter<HashBloom>);
	pendingHandle = pm->registerPluginData(&PluginData::simpleDataDeleter<PendingItem>);

	statsConn = make_shared<ManagedConnection>(pm->onCommand("stats",
		std::bind(&BloomManager::onStats, this, _1)));
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
			if(e.getPluginData(pendingHandle)) {
				// Already getting a blom - we'll end up with an old bloom but there's no trivial
				// way to avoid it...
				// TODO Queue the blom get?
				return;
			}

			size_t n = adchpp::Util::toInt(tmp);
			if(n == 0) {
				return;
			}

			e.clearPluginData(bloomHandle);

			size_t k = HashBloom::get_k(n, h);
			size_t m = HashBloom::get_m(n, k);

			e.setPluginData(pendingHandle, new PendingItem(m, k));

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

		PendingItem* pending = reinterpret_cast<PendingItem*>(e.getPluginData(pendingHandle));
		if(!pending) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_STATE, "Unexpected bloom filter update"));
			c.disconnect(Util::REASON_BAD_STATE);
			ok = false;
			return;
		}

		int64_t bytes = Util::toInt(cmd.getParam(3));

		if(bytes != static_cast<int64_t>(pending->m / 8)) {
			dcdebug("Disconnecting for invalid number of bytes: %d, %d\n", (int)bytes, (int)pending->m / 8);
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid number of bytes"));
			c.disconnect(Util::REASON_PLUGIN);
			ok = false;
			e.clearPluginData(pendingHandle);
			return;
		}

		c.setDataMode(bind(&BloomManager::onData, this, _1, _2, _3), bytes);
		ok = false;
	}
}

void BloomManager::onSend(Entity& c, const AdcCommand& cmd, bool& ok) {
	if(!ok)
		return;

	if(cmd.getCommand() == AdcCommand::CMD_SCH) {
		searches++;
		string tmp;
		if(cmd.getParam("TR", 0, tmp)) {
			tthSearches++;
			HashBloom* bloom = reinterpret_cast<HashBloom*>(c.getPluginData(bloomHandle));
			if((bloom && !bloom->match(TTHValue(tmp))) || !adchpp::Util::toInt(c.getField("SF"))) {
				ok = false;
				stopped++;
				dcdebug("Stopping search\n");
			}
		}
	}
}

std::pair<size_t, size_t> BloomManager::getBytes() const {
	std::pair<size_t, size_t> bytes;
	auto cm = ClientManager::getInstance();
	for(auto i = cm->getEntities().begin(), iend = cm->getEntities().end(); i != iend; ++i) {
		auto bloom = reinterpret_cast<HashBloom*>(i->second->getPluginData(bloomHandle));
		if(bloom) {
			bytes.first++;
			bytes.second += bloom->size();
		}
	}

	return bytes;
}

void BloomManager::onData(Entity& c, const uint8_t* data, size_t len) {
	PendingItem* pending = reinterpret_cast<PendingItem*>(c.getPluginData(pendingHandle));
	if(!pending) {
		// Shouldn't happen
		return;
	}

	pending->buffer.insert(pending->buffer.end(), data, data + len);

	if(pending->buffer.size() == pending->m / 8) {
		HashBloom* bloom = new HashBloom();
		c.setPluginData(bloomHandle, bloom);
		bloom->reset(pending->buffer, pending->k, h);
		c.clearPluginData(pendingHandle);
	}
}

void BloomManager::onStats(Entity& c) {
	string stats = "\nBloom filter statistics:";
	stats += "\nTotal outgoing searches: " + Util::toString(searches);
	stats += "\nOutgoing TTH searches: " + Util::toString(tthSearches) + " (" + Util::toString(tthSearches * 100. / searches) + "% of total)";
	stats += "\nStopped outgoing searches: " + Util::toString(stopped) + " (" + Util::toString(stopped * 100. / searches) + "% of total, " + Util::toString(stopped * 100. / tthSearches) + "% of TTH searches";
	auto bytes = getBytes();
	size_t clients = ClientManager::getInstance()->getEntities().size();
	stats += "\nClient support: " + Util::toString(bytes.first) + "/" + Util::toString(clients) + " (" + Util::toString(bytes.first * 100. / clients) + "%)";
	stats += "\nApproximate memory usage: " + Util::formatBytes(bytes.second) + ", " + Util::formatBytes(static_cast<double>(bytes.second) / clients) + "/client";
	c.send(AdcCommand(AdcCommand::CMD_MSG).addParam(stats));
}
