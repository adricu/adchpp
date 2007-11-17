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

#include "adchpp.h"

#include "Client.h"

#include "ClientManager.h"
#include "TimerManager.h"
#include "SettingsManager.h"

namespace adchpp {

using namespace std::tr1::placeholders;

Client* Client::create(const ManagedSocketPtr& ms) throw() {
	Client* c = new Client();
	c->setSocket(ms);
	return c;
}

Client::Client() throw() :
	sid(0), state(STATE_PROTOCOL), disconnecting(false), socket(0), dataBytes(0), floodTimer(0) {

}

namespace {
// Lightweight call forwarders, instead of tr1::bind
struct Handler {
	Handler(void (Client::*f)(), Client* c_) :
		c(c_), f0(f) {
	}
	Handler(void (Client::*f)(const ByteVector&), Client* c_) :
		c(c_), f1(f) {
	}

	void operator()() throw() {
		(c->*f0)();
	}
	void operator()(const ByteVector& bv) throw() {
		(c->*f1)(bv);
	}

	Client* c;
	union {
		void (Client::*f0)();
		void (Client::*f1)(const ByteVector&);
	};
};
}

void Client::setSocket(const ManagedSocketPtr& aSocket) throw() {
dcassert(!socket);
socket = aSocket;
socket->setConnectedHandler(Handler(&Client::onConnected, this));
socket->setDataHandler(Handler(&Client::onData, this));
socket->setFailedHandler(Handler(&Client::onFailed, this));
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

void Client::onData(const vector<uint8_t>& data) throw() {
dcdebug("In (%d): %.*s\n", data.size(), data.size(), &data[0]);

size_t done = 0;
size_t len = data.size();
while(!disconnecting && done < len) {
	if(dataBytes > 0) {
		size_t n = (size_t)min(dataBytes, (int64_t)(len - done));
		dataHandler(*this, &data[done], n);
		dataBytes -= n;
		done += n;
	} else {
		size_t j = done;
		while(j < len && data[j] != '\n')
		++j;

		if(j == len) {
			line.append((char*)&data[done], j - done);
			return;
		}
		line.append((char*)&data[done], j - done + 1); // include LF

		    done = j + 1;

		    if(SETTING(MAX_COMMAND_SIZE) > 0 && line.size() > (size_t)SETTING(MAX_COMMAND_SIZE)) {
			    send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Command too long"));
			    disconnect(Util::REASON_MAX_COMMAND_SIZE);
			    return;
		    }

		    if(line.size() == 1) {
			    line.clear();
			    continue;
		    }

		    try {
			    AdcCommand cmd(line);

			    if(cmd.getType() == 'H') {
				    cmd.setFrom(getSID());
			    } else if(cmd.getFrom() != getSID()) {
				    disconnect(Util::REASON_INVALID_SID);
				    return;
			    }
			    ClientManager::getInstance()->onReceive(*this, cmd);
		    } catch(const ParseException&) {
			    ClientManager::getInstance()->onBadLine(*this, line);
		    }
		    line.clear();
	    }
    }
}

void Client::setField(const char* name, const string& value) throw() {
    if(value.empty()) {
	    info.erase(AdcCommand::toCode(name));
    } else {
	    info[AdcCommand::toCode(name)] = value;
    }
    changed[AdcCommand::toCode(name)] = value;
    INF.clear();
}

bool Client::getChangedFields(AdcCommand& cmd) const throw() {
    for(InfMap::const_iterator i = changed.begin(); i != changed.end(); ++i)
    cmd.addParam(string((char*)&i->first, 2));
    return !changed.empty();
}
bool Client::getAllFields(AdcCommand& cmd) const throw() {
    for(InfMap::const_iterator i = info.begin(); i != info.end(); ++i)
    cmd.addParam(string((char*)&i->first, 2), i->second);
    return !info.empty();
}

const string& Client::getINF() const throw() {
    if(INF.empty()) {
	    AdcCommand cmd(AdcCommand::CMD_INF, AdcCommand::TYPE_BROADCAST, getSID());
	    getAllFields(cmd);
	    INF = cmd.toString();
    }
    return INF;
}

void Client::updateFields(const AdcCommand& cmd) throw() {
    dcassert(cmd.getCommand() == AdcCommand::CMD_INF);
    for(StringIterC j = cmd.getParameters().begin(); j != cmd.getParameters().end(); ++j) {
	    if(j->size() < 2)
	    continue;
	    setField(j->substr(0, 2).c_str(), j->substr(2));
    }
}

bool Client::isFiltered(const string& features) const {
    if(filters.empty()) {
	    return true;
    }

    for(size_t i = 0; i < features.size(); i += 5) {
	    if(features[i] == '-') {
		    if(std::find(filters.begin(), filters.end(), features.substr(i+1, 4)) != filters.end()) {
			    return true;
		    }
	    } else if(features[i] == '+') {
		    if(std::find(filters.begin(), filters.end(), features.substr(i+1, 4)) == filters.end()) {
			    return true;
		    }
	    }
    }
    return false;
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

void Client::disconnect(Util::Reason reason) throw() {
    if(socket && !disconnecting) {
	    disconnecting = true;
	    line.clear();
	    socket->disconnect(reason);
    }
}

void Client::onFailed() throw() {
    ClientManager::getInstance()->onFailed(*this);
    delete this;
}

}
