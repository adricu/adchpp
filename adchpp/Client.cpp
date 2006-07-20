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
#include "common.h"

#include "Client.h"

#include "ClientManager.h"
#include "TimerManager.h"

namespace adchpp {
	
Client* Client::create(u_int32_t sid) throw() {
	return new Client(sid);
}

Client::Client(u_int32_t aSID) throw() : sid(aSID), state(STATE_PROTOCOL), disconnecting(false), socket(0), dataBytes(0), floodTimer(0) { 

}

void Client::deleteThis() throw() {
	delete this;
}

void Client::setSocket(ManagedSocket* aSocket) throw() {
	dcassert(!socket);
	socket = aSocket;
	socket->setConnectedHandler(boost::bind(&Client::onConnected, this));
	socket->setDataHandler(boost::bind(&Client::onData, this, _1));
	socket->setFailedHandler(boost::bind(&Client::onFailed, this));
}

void Client::onConnected() throw() {
	dcdebug("Client::onConnected\n");
	ClientManager::getInstance()->onConnected(*this);
}

void* Client::setPSD(int id, void* data) throw() {
	PSDIter i = find_if(psd.begin(), psd.end(), CompareFirst<int, void*>(id));
	if(i != psd.end()) {
		void* old = i->second;
		i->second = data;
		return old;
	} else {
		psd.push_back(make_pair(id, data));
		return 0;
	}
}

void* Client::getPSD(int id) throw() {
	PSDIter i = find_if(psd.begin(), psd.end(), CompareFirst<int, void*>(id));
	if(i != psd.end())
		return i->second;
	else
		return 0;
}

void Client::onData(const vector<u_int8_t>& data) throw() {
	dcdebug("In (%d): %.*s\n", data.size(), data.size(), &data[0]);
	
	size_t i = 0;

	if(dataBytes > 0) {
		i = (size_t)min(dataBytes, (int64_t)data.size());
		dataHandler(&data[0], i);
		dataBytes -= i;
		if(i == data.size())
			return;
	}

	if(SETTING(MAX_COMMAND_SIZE) > 0 && line.size() > (size_t)SETTING(MAX_COMMAND_SIZE)) {
		Util::stats.disconOverflowIn++;
		disconnect();
		return;
	}

	size_t len = data.size();
	while(!disconnecting) {
		if(dataBytes > 0) {
			size_t n = (size_t)min(dataBytes, (int64_t)(data.size() - i));
			dataHandler(&data[0], i);
			dataBytes -= n;
			i += n;
		}

		size_t j = i;
		while(j < len && data[j] != '\n')
			++j;
		if(j == len) {
			if(i < len)
				line.append((char*)&data[i], len - i);
			return;
		}
		line.append((char*)&data[i], j - i + 1); // include LF
		i = j + 1;
		
		if(line.size() == 1) {
			line.clear();
			continue;
		}
		
		try {
			AdcCommand cmd(line);

			if(cmd.getType() == 'H') {
				cmd.setFrom(getSID());
			} else if(cmd.getFrom() != getSID()) {
				disconnect();
				line.clear();
				return;
			}
			ClientManager::getInstance()->onReceive(*this, cmd);
		} catch(const ParseException&) {
			ClientManager::getInstance()->onBadLine(*this, line);
		}
		line.clear();
	}
}	

void Client::updateFields(const AdcCommand& cmd) throw() {
	dcassert(cmd.getCommand() == AdcCommand::CMD_INF);
	for(StringIterC j = cmd.getParameters().begin(); j != cmd.getParameters().end(); ++j) {
		if(j->size() < 2)
			continue;
		setField(j->substr(0, 2).c_str(), j->substr(2));
	}
}

void Client::updateSupports(const AdcCommand& cmd) throw() {
	for(StringIterC i = cmd.getParameters().begin(); i != cmd.getParameters().end(); ++i) {
		const string& str = *i;
		if(str.size() != 6) {
			continue;
		}
		if(str.compare(0, 2, "AD") == 0) {
			supportList.push_back(str.substr(2));
		} else if(str.compare(0, 2, "RM") == 0) {
			supportList.erase(std::remove(supportList.begin(), supportList.end(), str.substr(2)), supportList.end());
		} else {
			continue;
		}
	}
}

bool Client::isFlooding(time_t addSeconds) {
	time_t now = GET_TIME();
	if(floodTimer < now) {
		floodTimer = now;
	}
	
	floodTimer += addSeconds;
	
	if(floodTimer > now + SETTING(FLOOD_THRESHOLD)) {
		return true;
	}
	
	return false;
}

void Client::onFailed() throw() {
	ClientManager::getInstance()->onFailed(*this);
	delete this;
}

}
