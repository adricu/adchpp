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

#include "ServerSocket.h"

#define MAX_CONNECTIONS SOMAXCONN

void ServerSocket::listen(short aPort) throw(SocketException) {
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
	if(::listen(sock, MAX_CONNECTIONS) == SOCKET_ERROR) {
		throw SocketException(errno);
	}
}

#ifdef HAVE_SYS_POLL_H
#include <sys/poll.h>

bool ServerSocket::isReady() const {
	struct pollfd pfd = { 0 };
	pfd.fd = sock;
	pfd.events = POLLIN;
	return poll(&pfd, 1, 0) != 0;
}
#endif