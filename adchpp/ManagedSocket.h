/* 
 * Copyright (C) 2006 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef MANAGEDSOCKET_H
#define MANAGEDSOCKET_H

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "Socket.h"
#include "CriticalSection.h"
#include "Signal.h"

class SocketManager;
class Writer;

#ifdef HAVE_SYS_EPOLL_H
#include <sys/epoll.h>
class EPoll;
#endif

/**
 * An asynchronous socket managed by SocketManager.
 */
class ManagedSocket {
public:
	void create() throw(SocketException) { sock.create(); }

	/** Asynchronous write */
	DLL void write(const char* buf, size_t len) throw();
	
	/** Asynchronous write, assumes that buffers are locked */
	DLL void fastWrite(const char* buf, size_t len, bool lowPrio = false) throw();
	
	/** Locks the write buffer for all sockets */
	static void lock() { outbufCS.enter(); }
	static void unlock() { outbufCS.leave(); }

	/** Asynchronous disconnect. Pending data will be written, but no more data will be read. */
	DLL void disconnect() throw();

	const string& getIp() const { return ip; }
	void setIp(const string& ip_) { ip = ip_; }
	
	bool isOpen() { return sock; }
	
	typedef boost::function<void()> ConnectedHandler;
	void setConnectedHandler(const ConnectedHandler& handler) { connectedHandler = handler; }
	typedef boost::function<void(const ByteVector&)> DataHandler;
	void setDataHandler(const DataHandler& handler) { dataHandler = handler; }
	typedef boost::function<void()> FailedHandler;
	void setFailedHandler(const FailedHandler& handler) { failedHandler = handler; }
private:

	ManagedSocket() throw();
	~ManagedSocket() throw();
	
	// Functions for Writer (called from Writer thread)
	socket_t getSocket() { return sock.getSocket(); }
	ByteVector* prepareWrite();
	bool completeWrite(ByteVector* buf, size_t written) throw();
	bool completeRead(ByteVector* buf) throw();
	void close() { ::shutdown(getSocket(), SD_SEND); sock.disconnect(); }
	
	// Functions processing data
	void processIncoming() throw();
	void processData(ByteVector* buf) throw();
	void processFail() throw();
	
	void ref() { refCount++; }
	void deref() { if(--refCount == 0) delete this; }
	
	// No copies
	ManagedSocket(const ManagedSocket&);
	ManagedSocket& operator=(const ManagedSocket&);

	friend class Writer;
#ifdef HAVE_SYS_EPOLL_H
	friend class EPoll;
#endif

	Socket sock;
	/** Output buffer, for storing data that's waiting to be transmitted */
	ByteVector* outBuf;
	/** Overflow timer, the buffer is allowed to overflow for 1 minute, then disconnect */
	u_int32_t overFlow;
	/** Disconnection scheduled for this socket */
	u_int32_t disc;
	/** Reference count, one for each thread that uses the instance */
	u_int32_t refCount;

	string ip;
#ifdef _WIN32
	/** Data currently being sent by WSASend, 0 if not sending */
	ByteVector* writeBuf;
	/** WSABUF for data being sent */
	WSABUF wsabuf;
#else
	struct epoll_event epoll;
#endif

	ConnectedHandler connectedHandler;
	DataHandler dataHandler;
	FailedHandler failedHandler;

	DLL static CriticalSection outbufCS;
};

#endif // MANAGEDSOCKET_H
