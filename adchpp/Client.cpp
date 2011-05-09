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

#include "adchpp.h"

#include "Client.h"

#include "ClientManager.h"
#include "TimeUtil.h"
#include "SocketManager.h"
#include "Core.h"

namespace adchpp {

using namespace std;
using namespace std::placeholders;

Client* Client::create(ClientManager &cm, const ManagedSocketPtr& ms, uint32_t sid) throw() {
	Client* c = new Client(cm, sid);
	c->setSocket(ms);
	return c;
}

Client::Client(ClientManager &cm, uint32_t sid_) throw() :
Entity(cm, sid_),
disconnecting(false),
dataBytes(0)
{
}

Client::~Client() {

}

namespace {
	// Lightweight call forwarders, instead of std::bind
	template<void (Client::*F)()>
	struct Handler0 {
		Handler0(Client* c_) : c(c_) { }
		void operator()() { (c->*F)(); }
		Client* c;
	};

	template<typename T, void (Client::*F)(const T&)>
	struct Handler1 {
		Handler1(Client* c_) : c(c_) { }
		void operator()(const T& bv) { (c->*F)(bv); }
		Client* c;
	};

	template<typename T, typename T2, void (Client::*F)(T, const T2&)>
	struct Handler2 {
		Handler2(Client* c_) : c(c_) { }
		void operator()(const T& t, const T2& t2) { (c->*F)(t, t2); }
		Client* c;
	};
}

void Client::setSocket(const ManagedSocketPtr& aSocket) throw() {
	dcassert(!socket);
	socket = aSocket;
	socket->setConnectedHandler(Handler0<&Client::onConnected>(this));
	socket->setDataHandler(Handler1<BufferPtr, &Client::onData>(this));
	socket->setFailedHandler(Handler2<Util::Reason, std::string, &Client::onFailed>(this));
}

void Client::onConnected() throw() {
	cm.onConnected(*this);
}

void Client::onData(const BufferPtr& buf) throw() {
	uint8_t* data = buf->data();
	size_t done = 0;
	size_t len = buf->size();
	while(!disconnecting && done < len) {
		if(dataBytes > 0) {
			size_t n = (size_t)min(dataBytes, (int64_t)(len - done));
			dataHandler(*this, data + done, n);
			dataBytes -= n;
			done += n;
		} else {
			size_t j = done;
			while(j < len && data[j] != '\n')
				++j;

			if(j == len) {
				if(!buffer) {
					if(done == 0) {
						buffer = buf;
					} else {
						buffer = make_shared<Buffer>(data + done, len - done);
					}
				} else {
					buffer->append(data + done, data + len);
				}
				return;
			} else if(!buffer) {
				if(done == 0 && j == len-1) {
					buffer = buf;
				} else {
					buffer = make_shared<Buffer>(data + done, j - done + 1);
				}
			} else {
				buffer->append(data + done, data + j + 1);
			}

			done = j + 1;

			if(cm.getMaxCommandSize() > 0 && buffer->size() > cm.getMaxCommandSize()) {
				send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Command too long"));
				disconnect(Util::REASON_MAX_COMMAND_SIZE);
				return;
			}

			if(buffer->size() == 1) {
				buffer.reset();
				continue;
			}

			try {
				AdcCommand cmd(buffer);

				if(cmd.getType() == 'H') {
					cmd.setFrom(getSID());
				} else if(cmd.getFrom() != getSID()) {
					disconnect(Util::REASON_INVALID_SID);
					return;
				}

				cm.onReceive(*this, cmd);
			} catch(const ParseException&) {
				cm.onBadLine(*this, string((char*)buffer->data(), buffer->size()));
			}

			buffer.reset();
		}
	}
}

void Client::disconnect(Util::Reason reason, const std::string &info) throw() {
	dcassert(socket);
	if(!disconnecting) {
		dcdebug("%s disconnecting because %d\n", AdcCommand::fromSID(getSID()).c_str(), reason);
		disconnecting = true;
		socket->disconnect(5000, reason, info);
	}
}

void Client::onFailed(Util::Reason reason, const std::string &info) throw() {
	cm.onFailed(*this, reason, info);
	delete this;
}

}
