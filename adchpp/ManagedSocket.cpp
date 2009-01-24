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

#include "ManagedSocket.h"

#include "SocketManager.h"
#include "TimerManager.h"
#include "SettingsManager.h"

namespace adchpp {

using namespace std;
using namespace std::tr1;
using namespace std::tr1::placeholders;

using namespace boost::asio;

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

	if(queued + buf->size() > (size_t)SETTING(MAX_BUFFER_SIZE)) {
		if(lowPrio && SETTING(KEEP_SLOW_USERS)) {
			return;
		} else if(overFlow > 0 && overFlow + SETTING(OVERFLOW_TIMEOUT) < GET_TICK()) {
			disconnect(Util::REASON_WRITE_OVERFLOW);
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

void ManagedSocket::prepareWrite() throw() {
	if(!outBuf.empty() && !writing) {
		if(outBuf.size() == 1) {
			sock.async_send(buffer(outBuf[0]->data(), outBuf[0]->size()), bind(&ManagedSocket::completeWrite, this, _1, _2));
		} else {
			std::vector<const_buffer> buffers(std::min(outBuf.size(), static_cast<size_t>(64)));

			for(size_t i = 0; i < buffers.size(); ++i) {
				buffers[i] = boost::asio::const_buffer(outBuf[i]->data(), outBuf[i]->size());
			}

			sock.async_send(buffers, bind(&ManagedSocket::completeWrite, this, _1, _2));
		}
		writing = true;
	}
}

void ManagedSocket::completeWrite(const boost::system::error_code& ec, size_t bytes) throw() {
	writing = false;
	if(!ec) {

		Stats::sendBytes += bytes;
		Stats::sendCalls++;

		while(bytes > 0) {
			BufferPtr p = *outBuf.begin();
			if(p->size() <= bytes) {
				bytes -= p->size();
				outBuf.erase(outBuf.begin());
			} else {
				p->erase_first(bytes);
				bytes = 0;
			}
		}

		size_t left = getQueuedBytes();
		if(overFlow > 0) {
			if(left < static_cast<size_t>(SETTING(MAX_BUFFER_SIZE))) {
				overFlow = 0;
			}
		}

		prepareWrite();
	} else {
		failSocket(0);
	}
}

void ManagedSocket::prepareRead() throw() {
	if(!readBuf) {
		readBuf = BufferPtr(new Buffer(SETTING(BUFFER_SIZE)));
		sock.async_read_some(buffer(readBuf->data(), readBuf->size()), bind(&ManagedSocket::completeRead, this, _1, _2));
	}
}

void ManagedSocket::completeRead(const boost::system::error_code& ec, size_t bytes) throw() {
	if(!ec) {
		Stats::recvBytes += bytes;
		Stats::recvCalls++;

		readBuf->resize(bytes);

		dataHandler(readBuf);
		readBuf.reset();

		prepareRead();
	} else {
		failSocket(0);
	}
}

void ManagedSocket::completeAccept(const boost::system::error_code& ec) throw() {
	if(!ec) {
		connectedHandler();
		prepareRead();
	} else {
		failSocket(0);
	}
}

void ManagedSocket::failSocket(int) throw() {
	if(failedHandler) {
		failedHandler();
		failedHandler = FailedHandler();
	}
}

void ManagedSocket::disconnect(Util::Reason reason) throw() {
	if(disc) {
		return;
	}

	disc = GET_TICK() + SETTING(DISCONNECT_TIMEOUT);
	Util::reasons[reason]++;
}

}
