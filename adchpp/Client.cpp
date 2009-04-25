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

#include "adchpp.h"

#include "Client.h"

#include "ClientManager.h"
#include "TimerManager.h"

namespace adchpp {

using namespace std;
using namespace std::tr1::placeholders;

size_t Client::defaultMaxCommandSize = 16 * 1024;

Client* Client::create(const ManagedSocketPtr& ms, uint32_t sid) throw() {
	Client* c = new Client(sid);
	c->setSocket(ms);
	return c;
}

Client::Client(uint32_t sid_) throw() : Entity(sid_), disconnecting(false),
	dataBytes(0), floodTimer(0), maxCommandSize(getDefaultMaxCommandSize()) {
}

Client::~Client() {

}

namespace {
	// Lightweight call forwarders, instead of tr1::bind
	struct Handler {
		Handler(void (Client::*f)(), Client* c_) : c(c_), f0(f) { }
		Handler(void (Client::*f)(const BufferPtr&), Client* c_) : c(c_), f1(f) { }

		void operator()() throw() {
			(c->*f0)();
		}
		void operator()(const BufferPtr& bv) throw() {
			(c->*f1)(bv);
		}

		Client* c;
		union {
			void (Client::*f0)();
			void (Client::*f1)(const BufferPtr&);
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
						buffer = BufferPtr(new Buffer(data + done, len - done));
					}
				} else {
					buffer->append(data + done, data + len);
				}
				return;
			} else if(!buffer) {
				if(done == 0 && j == len-1) {
					buffer = buf;
				} else {
					buffer = BufferPtr(new Buffer(data + done, j - done + 1));
				}
			} else {
				buffer->append(data + done, data + j + 1);
			}

			done = j + 1;

			if(getMaxCommandSize() > 0 && buffer->size() > getMaxCommandSize()) {
				send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Command too long"));
				disconnect(Util::REASON_MAX_COMMAND_SIZE);
				return;
			}

			if(buffer->size() == 1) {
				buffer = BufferPtr();
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
				ClientManager::getInstance()->onReceive(*this, cmd);
			} catch(const ParseException&) {
				ClientManager::getInstance()->onBadLine(*this, string((char*)buffer->data(), buffer->size()));
			}
			buffer = BufferPtr();
		}
	}
}

bool Client::isFlooding(time_t addSeconds) {
	time_t now = GET_TIME();
	if(floodTimer < now) {
		floodTimer = now;
	}

	floodTimer += addSeconds;

	/// @todo fix flood timer threshold
	if(false && floodTimer > now + 25) {
		return true;
	}

	return false;
}

void Client::disconnect(Util::Reason reason) throw() {
	if(socket && !disconnecting) {
		disconnecting = true;
		/// @todo fix timeout
		socket->disconnect(5000, reason);
	}
}

void Client::onFailed() throw() {
	ClientManager::getInstance()->onFailed(*this);
	delete this;
}

}
