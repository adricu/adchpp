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
class ManagedSocket : public intrusive_ptr_base<ManagedSocket>, boost::noncopyable {
public:
	ManagedSocket(const AsyncStreamPtr& sock_) : sock(sock_), overFlow(0), disc(0), maxBufferSize(getDefaultMaxBufferSize()), writing(false) { }

	/** Asynchronous write */
	ADCHPP_DLL void write(const BufferPtr& buf, bool lowPrio = false) throw();

	/** Returns the number of bytes in the output buffer; buffers must be locked */
	ADCHPP_DLL size_t getQueuedBytes() const;

	/** Asynchronous disconnect. Pending data will be written, but no more data will be read. */
	ADCHPP_DLL void disconnect(size_t timeout, Util::Reason reason) throw();

	const std::string& getIp() const { return ip; }
	void setIp(const std::string& ip_) { ip = ip_; }

	typedef std::tr1::function<void()> ConnectedHandler;
	void setConnectedHandler(const ConnectedHandler& handler) { connectedHandler = handler; }
	typedef std::tr1::function<void(const BufferPtr&)> DataHandler;
	void setDataHandler(const DataHandler& handler) { dataHandler = handler; }
	typedef std::tr1::function<void()> FailedHandler;
	void setFailedHandler(const FailedHandler& handler) { failedHandler = handler; }

	void setMaxBufferSize(size_t newSize) { maxBufferSize = newSize; }
	size_t getMaxBufferSize() { return maxBufferSize; }

	static void setDefaultMaxBufferSize(size_t newSize) { defaultMaxBufferSize = newSize; }
	static size_t getDefaultMaxBufferSize() { return defaultMaxBufferSize; }

	static size_t getOverflowTimeout() { return overflowTimeout; }

private:
	static size_t defaultMaxBufferSize;
	static size_t overflowTimeout;

	friend class SocketManager;
	friend class SocketFactory;
	friend void intrusive_ptr_release(ManagedSocket*);
	~ManagedSocket() throw();

	void completeAccept(const boost::system::error_code&) throw();
	void prepareWrite() throw();
	void completeWrite(const boost::system::error_code& ec, size_t bytes) throw();
	void prepareRead() throw();
	void completeRead(const boost::system::error_code& ec, size_t bytes) throw();

	void failSocket(const boost::system::error_code& error) throw();

	AsyncStreamPtr sock;

	/** Output buffer, for storing data that's waiting to be transmitted */
	BufferList outBuf;
	/** Input buffer */
	BufferPtr readBuf;

	/** Overflow timer, the buffer is allowed to overflow for 1 minute, then disconnect */
	uint32_t overFlow;
	/** Disconnection scheduled for this socket */
	uint32_t disc;

	/** Max allowed write buffer size for this socket */
	size_t maxBufferSize;

	bool writing;

	std::string ip;

	ConnectedHandler connectedHandler;
	DataHandler dataHandler;
	FailedHandler failedHandler;

};

}

#endif // MANAGEDSOCKET_H
