/*
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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

namespace adchpp {

using namespace std;

using namespace boost::asio;

ManagedSocket::ManagedSocket(SocketManager &sm, const AsyncStreamPtr &sock_) :
	sock(sock_),
	overflow(time::not_a_date_time),
	disc(time::not_a_date_time),
	lastWrite(time::not_a_date_time),
	sm(sm)
{ }

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
	if(buf->size() == 0 || disconnecting())
		return;

	size_t queued = getQueuedBytes();

	if(sm.getMaxBufferSize() > 0 && queued + buf->size() > sm.getMaxBufferSize()) {
		if(lowPrio) {
			return;
		} else if(!overflow.is_not_a_date_time() && overflow + time::millisec(sm.getOverflowTimeout()) < time::now()) {
			disconnect(5000, Util::REASON_WRITE_OVERFLOW);
			return;
		} else {
			overflow = time::now();
		}
	}

	sm.getStats().queueBytes += buf->size();
	sm.getStats().queueCalls++;

	outBuf.push_back(buf);

	prepareWrite();
}

// Simplified handlers to avoid bind complexity
namespace {

/** Keeper keeps a reference to the managed socket */
struct Keeper {
	Keeper(const ManagedSocketPtr& ms_) : ms(ms_) { }
	ManagedSocketPtr ms;

	void operator()(const boost::system::error_code& ec, size_t bytes) { }
};

template<void (ManagedSocket::*F)(const boost::system::error_code&, size_t)>
struct Handler : Keeper {
	Handler(const ManagedSocketPtr& ms) : Keeper(ms) { }

	void operator()(const boost::system::error_code& ec, size_t bytes) {
		(ms.get()->*F)(ec, bytes);
	}
};

struct Disconnector {
	Disconnector(const AsyncStreamPtr& stream_) : stream(stream_) { }
	void operator()() { stream->close(); }
	AsyncStreamPtr stream;
};

}

void ManagedSocket::prepareWrite() throw() {
	if(!writing()) {	// Not writing
		if(!outBuf.empty()) {
			lastWrite = time::now();
			sock->write(outBuf, Handler<&ManagedSocket::completeWrite>(shared_from_this()));
		}
	} else if(time::now() > lastWrite + time::seconds(60)) {
		disconnect(5000, Util::REASON_WRITE_TIMEOUT);
	}
}

void ManagedSocket::completeWrite(const boost::system::error_code& ec, size_t bytes) throw() {
	lastWrite = time::not_a_date_time;

	if(!ec) {
		sm.getStats().sendBytes += bytes;
		sm.getStats().sendCalls++;

		while(bytes > 0) {
			BufferPtr& p = *outBuf.begin();
			if(p->size() <= bytes) {
				bytes -= p->size();
				outBuf.erase(outBuf.begin());
			} else {
				p = make_shared<Buffer>(p->data() + bytes, p->size() - bytes);
				bytes = 0;
			}
		}

		if(!overflow.is_not_a_date_time()) {
			size_t left = getQueuedBytes();
			if(left < sm.getMaxBufferSize()) {
				overflow = time::not_a_date_time;
			}
		}

		if(disconnecting() && outBuf.empty()) {
			sock->shutdown(Keeper(shared_from_this()));
		} else {
			prepareWrite();
		}
	} else {
		fail(Util::REASON_SOCKET_ERROR, ec.message());
	}
}

void ManagedSocket::prepareRead() throw() {
	// We first send in an empty buffer to get notification when there's data available
	sock->prepareRead(BufferPtr(), Handler<&ManagedSocket::prepareRead2>(shared_from_this()));
}

void ManagedSocket::prepareRead2(const boost::system::error_code& ec, size_t) throw() {
	if(!ec) {
		// ADC commands are typically small - using a small buffer
		// helps with fairness
		// Calling available() on an ASIO socket seems to be terribly slow
		// Also, we might end up here if the socket has been closed, in which
		// case available would return 0 bytes...
		// We can't make a synchronous receive here because when using SSL
		// there might be data on the socket that won't translate into user data
		// and thus read_some will block
		// If there's no user data, this will effectively post a read operation
		// with a buffer and waste memory...to be continued.
		inBuf = make_shared<Buffer>(64);

		sock->prepareRead(inBuf, Handler<&ManagedSocket::completeRead>(shared_from_this()));
	} else {
		fail(Util::REASON_SOCKET_ERROR, ec.message());
	}
}

void ManagedSocket::completeRead(const boost::system::error_code& ec, size_t bytes) throw() {
	if(!ec) {
		try {
			sm.getStats().recvBytes += bytes;
			sm.getStats().recvCalls++;

			inBuf->resize(bytes);

			if(dataHandler) {
				dataHandler(inBuf);
			}

			inBuf.reset();
			prepareRead();
		} catch(const boost::system::system_error& e) {
			fail(Util::REASON_SOCKET_ERROR, e.code().message());
		}
	} else {
		inBuf.reset();
		fail(Util::REASON_SOCKET_ERROR, ec.message());
	}
}

void ManagedSocket::completeAccept(const boost::system::error_code& ec) throw() {
	if(!ec) {
		if(connectedHandler)
			connectedHandler();

		sock->init(std::bind(&ManagedSocket::ready, shared_from_this()));

	} else {
		fail(Util::REASON_SOCKET_ERROR, ec.message());
	}
}

void ManagedSocket::ready() throw() {
	if(readyHandler)
		readyHandler();

	prepareRead();
}

void ManagedSocket::fail(Util::Reason reason, const std::string &info) throw() {
	if(failedHandler) {
		failedHandler(reason, info);

		// using nullptr fails on older GCCs for which we're using nullptr.h; using 0 fails on VS...
#ifndef FAKE_NULLPTR
		connectedHandler = nullptr;
		readyHandler = nullptr;
		dataHandler = nullptr;
		failedHandler = nullptr;
#else
		connectedHandler = 0;
		readyHandler = 0;
		dataHandler = 0;
		failedHandler = 0;
#endif
	}
}

struct Reporter {
	Reporter(ManagedSocketPtr ms, void (ManagedSocket::*f)(Util::Reason reason, const std::string &info), Util::Reason reason, const std::string &info) :
		ms(ms), f(f), reason(reason), info(info) { }

	void operator()() { (ms.get()->*f)(reason, info); }

	ManagedSocketPtr ms;
	void (ManagedSocket::*f)(Util::Reason reason, const std::string &info);

	Util::Reason reason;
	std::string info;
};

void ManagedSocket::disconnect(size_t timeout, Util::Reason reason, const std::string &info) throw() {
	if(disconnecting()) {
		return;
	}

	disc = time::now() + time::millisec(timeout);

	sm.addJob(Reporter(shared_from_this(), &ManagedSocket::fail, reason, info));

	if(!writing()) {
		sock->shutdown(Keeper(shared_from_this()));
	}
	sm.addJob(timeout, Disconnector(sock));
}

bool ManagedSocket::disconnecting() const {
	return !disc.is_not_a_date_time();
}

bool ManagedSocket::writing() const {
	return !lastWrite.is_not_a_date_time();
}
}
