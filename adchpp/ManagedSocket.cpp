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

#include "ManagedSocket.h"

#include "SocketManager.h"
#include "TimerManager.h"

namespace adchpp {

using namespace std;

using namespace boost::asio;

size_t ManagedSocket::defaultMaxBufferSize = 16 * 1024;
time_t ManagedSocket::overflowTimeout = 60;

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
		} else if(overflow > 0 && overflow + getOverflowTimeout() < GET_TIME()) {
			disconnect(0, Util::REASON_WRITE_OVERFLOW);
			return;
		} else {
			overflow = GET_TIME();
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

	if(lastWrite != 0 && TimerManager::getTime() > lastWrite + 60) {
		sock->close();
	} else if(!outBuf.empty() && lastWrite == 0) {
		lastWrite = TimerManager::getTime();
		sock->write(outBuf, Handler<&ManagedSocket::completeWrite>(shared_from_this()));
	}
}

void ManagedSocket::completeWrite(const boost::system::error_code& ec, size_t bytes) throw() {
	lastWrite = 0;

	if(!ec) {
		Stats::sendBytes += bytes;
		Stats::sendCalls++;

		while(bytes > 0) {
			BufferPtr& p = *outBuf.begin();
			if(p->size() <= bytes) {
				bytes -= p->size();
				outBuf.erase(outBuf.begin());
			} else {
				p = std::make_shared<Buffer>(p->data() + bytes, p->size() - bytes);
				bytes = 0;
			}
		}

		if(overflow > 0) {
			size_t left = getQueuedBytes();
			if(left < getMaxBufferSize()) {
				overflow = 0;
			}
		}

		prepareWrite();
	} else {
		failSocket(ec);
	}
}

void ManagedSocket::prepareRead() throw() {
	sock->prepareRead(Handler<&ManagedSocket::completeRead>(shared_from_this()));
}

void ManagedSocket::completeRead(const boost::system::error_code& ec, size_t) throw() {
	if(!ec) {
		try {
			size_t bytes = sock->available();
			if(bytes) {
				BufferPtr readBuf = std::make_shared<Buffer>(bytes);

				bytes = sock->read(readBuf);

				Stats::recvBytes += bytes;
				Stats::recvCalls++;

				readBuf->resize(bytes);

				if(dataHandler)
					dataHandler(readBuf);
			}

			prepareRead();
		} catch(const boost::system::system_error& e) {
			failSocket(e.code());
		}
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

	// Schedule an extra socket close after the timeout in case the write doesn't
	// finish on time
	SocketManager::getInstance()->addJob(timeout, bind(&AsyncStream::close, sock));
}

}
