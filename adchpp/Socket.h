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

#ifndef ADCHPP_SOCKET_H
#define ADCHPP_SOCKET_H

#include "Util.h"
#include "Exception.h"

#ifndef _WIN32
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <fcntl.h>
#endif

namespace adchpp {
	
#ifdef _WIN32
// Berkely constants converted to the windows equivs...
#	define EWOULDBLOCK             WSAEWOULDBLOCK
#	ifdef errno
#		undef errno
#	endif

#	define errno ::WSAGetLastError()
#	define checksocket(x) if((x) == INVALID_SOCKET) { throw SocketException(::WSAGetLastError()); }
#	define checkrecv(x) if((x) == SOCKET_ERROR) { int a = ::WSAGetLastError(); if(a == EWOULDBLOCK) return -1; else throw SocketException(a); }
#	define checksockerr(x) if((x) == SOCKET_ERROR) { throw SocketException(::WSAGetLastError()); }
typedef int socklen_t;
typedef SOCKET socket_t;

#else

typedef int socket_t;
#define SOCKET_ERROR -1
#define INVALID_SOCKET -1
#	define closesocket(x) close(x)
#	define ioctlsocket(a, b, c) ioctl(a, b, c)
#	define checksocket(x) if((x) < 0) { throw SocketException(errno); }
#	define checkrecv(x) if((x) == SOCKET_ERROR) { int a = errno; if(a != EAGAIN) throw SocketException(a); }
#	define checksockerr(x) if((x) == SOCKET_ERROR) { throw SocketException(errno); }

#ifndef SD_SEND
#define SD_SEND SHUT_WR
#endif
#endif

class SocketException : public Exception {
public:
#ifdef _DEBUG
	SocketException(const string& aError) throw() : Exception("SocketException: " + aError) { }

	SocketException(int aError) throw() : 
	Exception("SocketException: " + errorToString(aError)) {
		dcdebug("Thrown: %s\n", error.c_str());
	}
#else //_DEBUG
	SocketException(const string& aError) throw() : Exception(aError) { }
	SocketException(int aError) throw() : Exception(errorToString(aError)) { }
#endif // _DEBUG
	
	virtual ~SocketException() throw() { }
private:
	static string errorToString(int aError) throw();
};

class Socket
{
public:
	enum {
		WAIT_NONE = 0x00,
		WAIT_CONNECT = 0x01,
		WAIT_READ = 0x02,
		WAIT_WRITE = 0x04
	};

	enum {
		TYPE_TCP,
		TYPE_UDP
	};

	Socket() throw(SocketException) : sock(INVALID_SOCKET) { }
	Socket(const string& aIp, const string& aPort) throw(SocketException) : sock(INVALID_SOCKET) { connect(aIp, aPort); }
	Socket(const string& aIp, short aPort) throw(SocketException) : sock(INVALID_SOCKET) { connect(aIp, aPort); }
	virtual ~Socket() throw() { disconnect(); }

	virtual void create(int aType = TYPE_TCP) throw(SocketException);
	virtual void bind(short aPort) throw(SocketException);
	virtual void connect(const string& aIp, short aPort) throw(SocketException);
	void connect(const string& aIp, const string& aPort) throw(SocketException) { connect(aIp, (short)Util::toInt(aPort)); }
	virtual void accept(const Socket& aSocket) throw(SocketException);
	virtual void write(const char* aBuffer, size_t aLen) throw(SocketException);
	void write(const string& aData) throw(SocketException) { write(aData.data(), aData.length()); }
	virtual int writeNB(const char* aBuffer, size_t aLen) throw(SocketException);
	int writeNB(const string& aData) throw(SocketException) { return writeNB(aData.data(), aData.length()); }
	virtual void writeTo(const string& aIp, short aPort, const char* aBuffer, size_t aLen) throw(SocketException);
	void writeTo(const string& aIp, short aPort, const string& aData) throw(SocketException) { writeTo(aIp, aPort, aData.data(), aData.length()); }
	virtual void disconnect() throw();

	void listen(short aPort) throw(SocketException);

	void shutdown() { ::shutdown(sock, 1); }
	
	int read(void* aBuffer, size_t aBufLen) throw(SocketException); 
	int wait(uint32_t millis, int waitFor) throw(SocketException);
	
	static string resolve(const string& aDns);
	
	int getAvailable() {
		u_long i = 0;
		ioctlsocket(sock, FIONREAD, &i);
		return i;
	}

#ifdef _WIN32
	void setBlocking(bool block) throw() {
		u_long b = block ? 0 : 1;
		ioctlsocket(sock, FIONBIO, &b);
	}
#else
	void setBlocking(bool block) throw() {
		int v = fcntl(sock, F_GETFD, 0);
		fcntl(sock, F_SETFD, block ? (v & ~O_NONBLOCK) : (v | O_NONBLOCK));
	}
#endif
	
	string getLocalIp() throw();
	int getLocalPort() throw();	
	socket_t getSocket() { return sock; }
	
	operator bool() const { return sock != INVALID_SOCKET; }

protected:
	socket_t sock;
private:
	Socket(const Socket&);
	Socket& operator=(const Socket&);

};

}

#endif // _SOCKET_H
