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

#ifndef ADCHPP_MANAGEDSOCKET_H
#define ADCHPP_MANAGEDSOCKET_H

#include "common.h"

#include "forward.h"
#include "Signal.h"
#include "Util.h"
#include "Buffer.h"
#include "AsyncStream.h"
#include "TimeUtil.h"

namespace adchpp {

/**
 * An asynchronous socket managed by SocketManager.
 */
class ManagedSocket : private boost::noncopyable, public enable_shared_from_this<ManagedSocket> {
public:
	ManagedSocket(SocketManager &sm, const AsyncStreamPtr& sock_);

	/** Asynchronous write */
	ADCHPP_DLL void write(const BufferPtr& buf, bool lowPrio = false) throw();

	/** Returns the number of bytes in the output buffer; buffers must be locked */
	ADCHPP_DLL size_t getQueuedBytes() const;

	/** Asynchronous disconnect. Pending data will be written, but no more data will be read. */
	ADCHPP_DLL void disconnect(size_t timeout, Util::Reason reason, const std::string &info = Util::emptyString) throw();

	const std::string& getIp() const { return ip; }
	void setIp(const std::string& ip_) { ip = ip_; }

	typedef std::function<void()> ConnectedHandler;
	void setConnectedHandler(const ConnectedHandler& handler) { connectedHandler = handler; }

	typedef std::function<void()> ReadyHandler;
	void setReadyHandler(const ReadyHandler& handler) { readyHandler = handler; }

	typedef std::function<void(const BufferPtr&)> DataHandler;
	void setDataHandler(const DataHandler& handler) { dataHandler = handler; }

	typedef std::function<void(Util::Reason, const std::string &)> FailedHandler;
	void setFailedHandler(const FailedHandler& handler) { failedHandler = handler; }

	time::ptime getOverflow() { return overflow; }

	time::ptime getLastWrite() { return lastWrite; }

	~ManagedSocket() throw();

private:
	friend class SocketManager;
	friend class SocketFactory;

	void completeAccept(const boost::system::error_code&) throw();
	void ready() throw();
	void prepareWrite() throw();
	void completeWrite(const boost::system::error_code& ec, size_t bytes) throw();
	void prepareRead() throw();
	void prepareRead2(const boost::system::error_code& ec, size_t bytes) throw();
	void completeRead(const boost::system::error_code& ec, size_t bytes) throw();

	void fail(Util::Reason reason, const std::string &info) throw();

	bool disconnecting() const;
	bool writing() const;

	AsyncStreamPtr sock;

	/** Output buffer, for storing data that's waiting to be transmitted */
	BufferList outBuf;

	/** Input buffer used when receiving data */
	BufferPtr inBuf;

	/** Overflow timer, the time when the socket started to overflow */
	time::ptime overflow;

	/** Time when this socket will be disconnected regardless of buffers */
	time::ptime disc;

	/** Last time that a write started, 0 if no active write */
	time::ptime lastWrite;

	std::string ip;

	ConnectedHandler connectedHandler;
	ReadyHandler readyHandler;
	DataHandler dataHandler;
	FailedHandler failedHandler;

	SocketManager &sm;
};

}

#endif // MANAGEDSOCKET_H
