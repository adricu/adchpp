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

#ifndef ADCHPP_MANAGEDSOCKET_H
#define ADCHPP_MANAGEDSOCKET_H

#include "common.h"

#include "forward.h"
#include "Mutex.h"
#include "Signal.h"
#include "Util.h"
#include "Buffer.h"
#include "AsyncStream.h"

namespace adchpp {

/**
 * An asynchronous socket managed by SocketManager.
 */
class ManagedSocket : private boost::noncopyable, public std::enable_shared_from_this<ManagedSocket> {
public:
	ManagedSocket(const AsyncStreamPtr& sock_) : sock(sock_), overflow(0), disc(0), maxBufferSize(getDefaultMaxBufferSize()), lastWrite(0) { }

	/** Asynchronous write */
	ADCHPP_DLL void write(const BufferPtr& buf, bool lowPrio = false) throw();

	/** Returns the number of bytes in the output buffer; buffers must be locked */
	ADCHPP_DLL size_t getQueuedBytes() const;

	/** Asynchronous disconnect. Pending data will be written, but no more data will be read. */
	ADCHPP_DLL void disconnect(size_t timeout, Util::Reason reason) throw();

	const std::string& getIp() const { return ip; }
	void setIp(const std::string& ip_) { ip = ip_; }

	typedef std::function<void()> ConnectedHandler;
	void setConnectedHandler(const ConnectedHandler& handler) { connectedHandler = handler; }
	typedef std::function<void(const BufferPtr&)> DataHandler;
	void setDataHandler(const DataHandler& handler) { dataHandler = handler; }
	typedef std::function<void()> FailedHandler;
	void setFailedHandler(const FailedHandler& handler) { failedHandler = handler; }

	void setMaxBufferSize(size_t newSize) { maxBufferSize = newSize; }
	size_t getMaxBufferSize() { return maxBufferSize; }

	time_t getOverflow() { return overflow; }

	time_t getLastWrite() { return lastWrite; }

	static void setDefaultMaxBufferSize(size_t newSize) { defaultMaxBufferSize = newSize; }
	static size_t getDefaultMaxBufferSize() { return defaultMaxBufferSize; }

	static time_t getOverflowTimeout() { return overflowTimeout; }
	~ManagedSocket() throw();

private:
	static size_t defaultMaxBufferSize;
	static time_t overflowTimeout;

	friend class SocketManager;
	friend class SocketFactory;

	void completeAccept(const boost::system::error_code&) throw();
	void prepareWrite() throw();
	void completeWrite(const boost::system::error_code& ec, size_t bytes) throw();
	void prepareRead() throw();
	void completeRead(const boost::system::error_code& ec, size_t bytes) throw();

	void failSocket(const boost::system::error_code& error) throw();

	AsyncStreamPtr sock;

	/** Output buffer, for storing data that's waiting to be transmitted */
	BufferList outBuf;

	/** Overflow timer, the time when the socket started to overflow */
	time_t overflow;
	/** Disconnection scheduled for this socket */
	uint32_t disc;

	/** Max allowed write buffer size for this socket */
	size_t maxBufferSize;

	/** Last time that a write started, 0 if no active write */
	time_t lastWrite;

	std::string ip;

	ConnectedHandler connectedHandler;
	DataHandler dataHandler;
	FailedHandler failedHandler;

};

}

#endif // MANAGEDSOCKET_H
