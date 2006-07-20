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

#include "stdinc.h"
#include "common.h"

#include "Socket.h"

namespace adchpp {
	
string SocketException::errorToString(int aError) throw() {
	return Util::translateError(aError);
}

void Socket::create(int aType /* = TYPE_TCP */) throw(SocketException) {
	if(sock != INVALID_SOCKET)
		Socket::disconnect();

	switch(aType) {
	case TYPE_TCP:
		{
#ifdef _WIN32
			checksocket(sock = WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, 0, 0, WSA_FLAG_OVERLAPPED));
			setBlocking(false);
			DWORD x = 0;
			setsockopt(sock, SOL_SOCKET, SO_SNDBUF, (char*)&x, sizeof(x));
#else
			checksocket(sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP));
			setBlocking(false);
#endif
		}
		break;
	case TYPE_UDP:
		checksocket(sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP));
		break;
	default:
		dcasserta(0);
	}
}

/**
 * Binds an UDP socket to a certain local port.
 */
void Socket::bind(short aPort) throw (SocketException){
	sockaddr_in sock_addr;
		
	sock_addr.sin_family = AF_INET;
	sock_addr.sin_port = htons(aPort);
	sock_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    checksockerr(::bind(sock, (sockaddr *)&sock_addr, sizeof(sock_addr)));
}

void Socket::listen(short aPort) throw(SocketException) {
	disconnect();
	
	sockaddr_in tcpaddr;
#ifdef _WIN32
	sock = WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, 0, 0, WSA_FLAG_OVERLAPPED);
#else
	sock = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
#endif
	int x = 1;
	::setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char*)&x, sizeof(int));
	
	if(sock == (socket_t)-1) {
		throw SocketException(errno);
	}

	tcpaddr.sin_family = AF_INET;
	tcpaddr.sin_port = htons(aPort);
	tcpaddr.sin_addr.s_addr = htonl(INADDR_ANY);
	
	if(::bind(sock, (sockaddr *)&tcpaddr, sizeof(tcpaddr)) == SOCKET_ERROR) {
		throw SocketException(errno);
	}
	if(::listen(sock, SOMAXCONN) == SOCKET_ERROR) {
		throw SocketException(errno);
	}
}

void Socket::accept(const Socket& aSocket) throw(SocketException){
	if(sock != INVALID_SOCKET) {
		Socket::disconnect();
	}

	sockaddr_in sock_addr;
	socklen_t sz = sizeof(sock_addr);

	checksockerr(sock=::accept(aSocket.sock, (sockaddr*)&sock_addr, &sz));
}

/**
 * Connects a socket to an address/ip, closing any other connections made with
 * this instance.
 * @param aAddr Server address, in dns or xxx.xxx.xxx.xxx format.
 * @param aPort Server port.
 * @throw SocketException If any connection error occurs.
 */
void Socket::connect(const string& aAddr, short aPort) throw(SocketException) {
	sockaddr_in  serv_addr;
	hostent* host;

	if(sock == INVALID_SOCKET) {
		create();
	}

	memset(&serv_addr, 0, sizeof(serv_addr));
   	serv_addr.sin_port = htons(aPort);
	serv_addr.sin_family = AF_INET;
	
	serv_addr.sin_addr.s_addr = inet_addr(aAddr.c_str());

    if (serv_addr.sin_addr.s_addr == INADDR_NONE) {   /* server address is a name or invalid */
        host = gethostbyname(aAddr.c_str());
        if (host == NULL) {
            throw SocketException(errno);
        }
        serv_addr.sin_addr.s_addr = *((u_int32_t*)host->h_addr);
    }

    if(::connect(sock,(sockaddr*)&serv_addr,sizeof(serv_addr)) == SOCKET_ERROR) {
		// EWOULDBLOCK is ok, the attempt is still being made, and FD_CONNECT will be signaled...
		if(errno != EWOULDBLOCK) {
			checksockerr(SOCKET_ERROR);
		} 
	}
}

/**
 * Reads zero to aBufLen characters from this socket, 
 * @param aBuffer A buffer to store the data in.
 * @param aBufLen Size of the buffer.
 * @return Number of bytes read, 0 if disconnected and -1 if the call would block.
 * @throw SocketException On any failure.
 */
int Socket::read(void* aBuffer, size_t aBufLen) throw(SocketException) {
	int len = 0;

	checkrecv(len=::recv(sock, (char*)aBuffer, (int)aBufLen, 0));

	dcdebug("In (%d): %.30s\n", len, (char*)aBuffer);
	Util::stats.totalDown += len;
	return len;
}

void Socket::write(const char* aBuffer, size_t aLen) throw(SocketException) {
	size_t pos = writeNB(aBuffer, aLen);
	while(pos < aLen) {
		// Try once every second at least, you never know...
		wait(1000, WAIT_WRITE);
		pos += writeNB(aBuffer + pos, aLen - pos);
	}
}

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0
#endif

#ifndef MSG_DONTWAIT
#define MSG_DONTWAIT 0
#endif

/**
 * Sends data, will block until all data has been sent or an exception occurs
 * @param aBuffer Buffer with data
 * @param aLen Data length
 * @return 0 if socket would block, otherwise the number of bytes written
 * @throw SocketExcpetion Send failed.
 */
int Socket::writeNB(const char* aBuffer, size_t aLen) throw(SocketException) {
//	dcdebug("Writing %db: %.100s\n", aLen, aBuffer);
	dcassert(aLen > 0);

	int i = ::send(sock, aBuffer, (int)aLen, MSG_NOSIGNAL | MSG_DONTWAIT);
	if(i == SOCKET_ERROR) {
		if(errno == EWOULDBLOCK) {
			return 0;
		}
		checksockerr(i);
	}
	dcdebug("Out (%d/%d): %.30s\n", i, aLen, (char*)aBuffer);
	
	Util::stats.totalUp += i;

	return i;
}

/**
 * Sends data, will block until all data has been sent or an exception occurs
 * @param aIp Server IP, in xxx.xxx.xxx.xxx format.
 * @param port Server port.
 * @param aBuffer Buffer with data
 * @param aLen Data length
 * @throw SocketExcpetion Send failed.
 */
void Socket::writeTo(const string& aIp, short aPort, const char* aBuffer, size_t aLen) throw(SocketException) {
	if(sock == INVALID_SOCKET) {
		create(TYPE_UDP);
	}

	//	dcdebug("Writing %db: %.100s\n", aLen, aBuffer);
	dcassert(aLen > 0);
	dcassert(aLen < 1450);
	dcassert(sock != INVALID_SOCKET);

	sockaddr_in  serv_addr;
	hostent* host;

	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_port = htons(aPort);
	serv_addr.sin_family = AF_INET;

	serv_addr.sin_addr.s_addr = inet_addr(aIp.c_str());

	if (serv_addr.sin_addr.s_addr == INADDR_NONE) {   /* server address is a name or invalid */
		host = gethostbyname(aIp.c_str());
		if (host == NULL) {
			throw SocketException(errno);
		}
		serv_addr.sin_addr.s_addr = *((u_int32_t*)host->h_addr);
	}

	int i = ::sendto(sock, aBuffer, (int)aLen, 0, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
	checksockerr(i);

	Util::stats.totalUp += i;
}

/**
 * Blocks until timeout is reached one of the specified conditions have been fulfilled
 * @param millis Max milliseconds to block.
 * @param waitFor WAIT_*** flags that set what we're waiting for, set to the combination of flags that
 *				  triggered the wait stop on return (==WAIT_NONE on timeout)
 * @return WAIT_*** ored together of the current state.
 * @throw SocketException Select or the connection attempt failed.
 */
int Socket::wait(u_int32_t millis, int waitFor) throw(SocketException) {
#ifdef HAVE_POLL_H
	struct pollfd fd;
	fd.fd = sock;
	fd.events = 0;
	if(waitFor & WAIT_READ || waitFor & WAIT_CONNECT) {
		fd.events |= POLLIN;
	}
	if(waifFor & WAIT_WRITE) {
		fd.events |= POLLOUT;
	}
	
	int result = poll(&fd, 1, millis));
	if(result == 1) {
		if(fd.revents & POLLERR) {
			int y = 0;
			socklen_t z = sizeof(y);
			checksockerr(getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&y, &z));
			if(y != 0) {
				throw SocketException(y);
			}
			// Should never happen
			throw SocketException("Unknown socket error");
		}			

		int ret = 0;
		if(fr.revents & POLLIN) {
			ret |= waitFor & (WAIT_READ | WAIT_CONNECT);
		}
		if(fd.revents & POLLOUT) {
			ret |= WAIT_WRITE;
		}
		return ret;
	} else if(result == -1) {
		throw SocketException(errno);
	}
	
	return 0;
#else
	
	timeval tv;
	fd_set rfd, wfd, efd;
	fd_set *rfdp = NULL, *wfdp = NULL;
	tv.tv_sec = millis/1000;
	tv.tv_usec = (millis%1000)*1000; 

	if(waitFor & WAIT_CONNECT) {
		dcassert(!(waitFor & WAIT_READ) && !(waitFor & WAIT_WRITE));

		FD_ZERO(&rfd);
		FD_ZERO(&efd);

		FD_SET(sock, &rfd);
		FD_SET(sock, &efd);
		checksockerr(select((int)(sock+1), &rfd, 0, &efd, &tv));

		if(FD_ISSET(sock, &rfd)) {
			return WAIT_CONNECT;
		}
		
		int y = 0;
		socklen_t z = sizeof(y);
		checksockerr(getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&y, &z));

		if(y != 0)
			throw SocketException(y);
		// Should never happen
		throw SocketException("Unknown socket error");
	}

	if(waitFor & WAIT_READ) {
		dcassert(!(waitFor & WAIT_CONNECT));
		rfdp = &rfd;
		FD_ZERO(rfdp);
		FD_SET(sock, rfdp);
	}
	if(waitFor & WAIT_WRITE) {
		dcassert(!(waitFor & WAIT_CONNECT));
		wfdp = &wfd;
		FD_ZERO(wfdp);
		FD_SET(sock, wfdp);
	}
	waitFor = WAIT_NONE;
	checksockerr(select((int)(sock+1), rfdp, wfdp, NULL, &tv));

	if(rfdp && FD_ISSET(sock, rfdp)) {
		waitFor |= WAIT_READ;
	}
	if(wfdp && FD_ISSET(sock, wfdp)) {
		waitFor |= WAIT_WRITE;
	}

	return waitFor;
#endif
}

string Socket::resolve(const string& aDns) {
	sockaddr_in sock_addr;

	memset(&sock_addr, 0, sizeof(sock_addr));
	sock_addr.sin_port = 0;
	sock_addr.sin_family = AF_INET;
	sock_addr.sin_addr.s_addr = inet_addr(aDns.c_str());

	if (sock_addr.sin_addr.s_addr == INADDR_NONE) {   /* server address is a name or invalid */
		hostent* host;
		host = gethostbyname(aDns.c_str());
		if (host == NULL) {
			return Util::emptyString;
		}
		sock_addr.sin_addr.s_addr = *((u_int32_t*)host->h_addr);
		return inet_ntoa(sock_addr.sin_addr);
	} else {
		return aDns;
	}
}

string Socket::getLocalIp() throw() {
	if(sock == INVALID_SOCKET)
		return Util::emptyString;

	sockaddr_in sock_addr;
	socklen_t len = sizeof(sock_addr);
	if(getsockname(sock, (sockaddr*)&sock_addr, &len) == 0) {
		return inet_ntoa(sock_addr.sin_addr);
	}
	return Util::emptyString;
}

int Socket::getLocalPort() throw() {
	sockaddr_in sock_addr;
	socklen_t len = sizeof(sock_addr);
	if(getsockname(sock, (sockaddr*)&sock_addr, &len) == 0) {
		return (int)sock_addr.sin_port;
	}
	return -1;
}

void Socket::disconnect() throw() {
	if(sock != INVALID_SOCKET) {
		::shutdown(sock, 1); // Make sure we send FIN (SD_SEND shutdown type...)
		closesocket(sock);
	}

	sock = INVALID_SOCKET;
}

}
