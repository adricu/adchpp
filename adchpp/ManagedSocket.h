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

#ifndef ADCHPP_MANAGEDSOCKET_H
#define ADCHPP_MANAGEDSOCKET_H

#include "common.h"

#include "forward.h"
#include "Socket.h"
#include "Mutex.h"
#include "Signal.h"
#include "Util.h"

namespace adchpp {
	
/**
 * An asynchronous socket managed by SocketManager.
 */
class ManagedSocket : public intrusive_ptr_base {
public:
	void create() throw(SocketException) { sock.create(); }

	/** Asynchronous write */
	ADCHPP_DLL void write(const char* buf, size_t len) throw();
	
	/** Asynchronous write, assumes that buffers are locked */
	ADCHPP_DLL bool fastWrite(const char* buf, size_t len, bool lowPrio = false) throw();
	
	/** Returns the lock used for the write buffers */
	static FastMutex& getWriteMutex() { return writeMutex; }
	
	/** Returns the number of bytes in the output buffer; buffers must be locked */
	size_t getQueuedBytes() { return outBuf ? outBuf->size() : 0; }

	/** Asynchronous disconnect. Pending data will be written, but no more data will be read. */
	ADCHPP_DLL void disconnect(Util::Reason reason) throw();

	const std::string& getIp() const { return ip; }
	void setIp(const std::string& ip_) { ip = ip_; }
	
	typedef std::tr1::function<void()> ConnectedHandler;
	void setConnectedHandler(const ConnectedHandler& handler) { connectedHandler = handler; }
	typedef std::tr1::function<void(const ByteVector&)> DataHandler;
	void setDataHandler(const DataHandler& handler) { dataHandler = handler; }
	typedef std::tr1::function<void()> FailedHandler;
	void setFailedHandler(const FailedHandler& handler) { failedHandler = handler; }

	socket_t getSocket() { return sock.getSocket(); }
	operator bool() const { return sock; }
private:

	ManagedSocket() throw();
	~ManagedSocket() throw();
	
	// Functions for Writer (called from Writer thread)
	ByteVector* prepareWrite();
	void completeAccept() throw();
	bool completeWrite(ByteVector* buf, size_t written) throw();
	bool completeRead(ByteVector* buf) throw();
	void failSocket(int error) throw();
	
	void shutdown() { sock.shutdown(); }
	void close() { sock.disconnect(); }
	
	// Functions processing events
	void processData(ByteVector* buf) throw();
	
	// No copies
	ManagedSocket(const ManagedSocket&);
	ManagedSocket& operator=(const ManagedSocket&);

	friend class Writer;

	Socket sock;
	/** Output buffer, for storing data that's waiting to be transmitted */
	ByteVector* outBuf;
	/** Overflow timer, the buffer is allowed to overflow for 1 minute, then disconnect */
	uint32_t overFlow;
	/** Disconnection scheduled for this socket */
	uint32_t disc;

	std::string ip;
#ifdef _WIN32
	/** Data currently being sent by WSASend, 0 if not sending */
	ByteVector* writeBuf;
	/** WSABUF for data being sent */
	WSABUF wsabuf;
	
	bool isBlocked() { return writeBuf != 0; }
#else
	bool blocked;
	bool isBlocked() { return blocked; }
	void setBlocked(bool blocked_) { blocked = blocked_; }
#endif

	ConnectedHandler connectedHandler;
	DataHandler dataHandler;
	FailedHandler failedHandler;

	ADCHPP_DLL static FastMutex writeMutex;
};

}

#endif // MANAGEDSOCKET_H
