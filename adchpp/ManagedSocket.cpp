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

#include "ManagedSocket.h"

#include "SocketManager.h"
#include "TimerManager.h"

namespace adchpp {

using namespace std;
using namespace std::tr1;

using namespace boost::asio;

size_t ManagedSocket::defaultMaxBufferSize = 16 * 1024;
size_t ManagedSocket::overflowTimeout = 60 * 1000;

ManagedSocket::~ManagedSocket() throw() {
	dcdebug("ManagedSocket deleted\n");
}

static size_t sum(const BufferList& l) {
	size_t bytes = 0;
	for(BufferList::const_iterator i = l.begin(); i != l.end(); ++i) {
		bytes += (*i)->size();
	}
	return bytes;
}

size_t ManagedSocket::getQueuedBytes() const {
	return sum(outBuf);
}

void ManagedSocket::write(const BufferPtr& buf, bool lowPrio /* = false */) throw() {
	if((buf->size() == 0) || (disc > 0))
		return;

	size_t queued = getQueuedBytes();

	if(getMaxBufferSize() > 0 && queued + buf->size() > getMaxBufferSize()) {
		if(lowPrio) {
			return;
		} else if(overFlow > 0 && overFlow + getOverflowTimeout() < GET_TICK()) {
			disconnect(0, Util::REASON_WRITE_OVERFLOW);
			return;
		} else {
			overFlow = GET_TICK();
		}
	}

	Stats::queueBytes += buf->size();
	Stats::queueCalls++;

	outBuf.push_back(buf);

	prepareWrite();
}

// Simplified handler to avoid bind complexity
namespace {
template<void (ManagedSocket::*F)(const boost::system::error_code&, size_t)>
struct Handler {
	Handler(const ManagedSocketPtr& ms_) : ms(ms_) { }
	ManagedSocketPtr ms;

	void operator()(const boost::system::error_code& ec, size_t bytes) {
		(ms.get()->*F)(ec, bytes);
	}
};
}

void ManagedSocket::prepareWrite() throw() {
	if(disc > 0) {
		if(outBuf.empty() || GET_TICK() >= disc) {
			sock->close();
			return;
		}
	}

	if(!outBuf.empty() && !writing) {
		writing = true;
		sock->write(outBuf, Handler<&ManagedSocket::completeWrite>(from_this()));
	}
}

void ManagedSocket::completeWrite(const boost::system::error_code& ec, size_t bytes) throw() {
	writing = false;
	if(!ec) {
		Stats::sendBytes += bytes;
		Stats::sendCalls++;

		while(bytes > 0) {
			BufferPtr& p = *outBuf.begin();
			if(p->size() <= bytes) {
				bytes -= p->size();
				outBuf.erase(outBuf.begin());
			} else {
				outBuf[0] = BufferPtr(new Buffer(p->data(), p->size() - bytes));
				bytes = 0;
			}
		}

		if(overFlow > 0) {
			size_t left = getQueuedBytes();
			if(left < getMaxBufferSize()) {
				overFlow = 0;
			}
		}

		prepareWrite();
	} else {
		sock->close();
	}
}

void ManagedSocket::prepareRead() throw() {
	if(!readBuf) {
		readBuf = BufferPtr(new Buffer(Buffer::getDefaultBufferSize()));
		sock->read(readBuf, Handler<&ManagedSocket::completeRead>(from_this()));
	}
}

void ManagedSocket::completeRead(const boost::system::error_code& ec, size_t bytes) throw() {
	if(!ec) {
		Stats::recvBytes += bytes;
		Stats::recvCalls++;

		readBuf->resize(bytes);

		if(dataHandler)
			dataHandler(readBuf);
		readBuf.reset();

		prepareRead();
	} else {
		failSocket(ec);
	}
}

void ManagedSocket::completeAccept(const boost::system::error_code& ec) throw() {
	if(!ec) {
		if(connectedHandler)
			connectedHandler();
		prepareRead();
	} else {
		failSocket(ec);
	}
}

void ManagedSocket::failSocket(const boost::system::error_code& code) throw() {
	SocketManager::getInstance()->errors[code.message()]++;
	if(failedHandler) {
		failedHandler();
		failedHandler = FailedHandler();
		dataHandler = DataHandler();
		connectedHandler = ConnectedHandler();
	}
}

void ManagedSocket::disconnect(size_t timeout, Util::Reason reason) throw() {
	if(!disc) {
		disc = GET_TICK() + timeout;
		Util::reasons[reason]++;
	}

	prepareWrite();
}

}
