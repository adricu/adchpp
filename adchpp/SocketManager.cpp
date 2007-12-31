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

#include "SocketManager.h"

#include "LogManager.h"
#include "TimerManager.h"
#include "SettingsManager.h"
#include "Semaphores.h"
#include "ManagedSocket.h"
#include "Thread.h"

#ifdef _WIN32
#include <mswsock.h>
#endif

#ifdef HAVE_SYS_EPOLL_H
#include <sys/epoll.h>
#endif

namespace adchpp {

using namespace std;
using namespace std::tr1;

static uint32_t WRITE_TIMEOUT = 100;

#ifdef _WIN32

#define ACCEPT_BUF_SIZE ((sizeof(SOCKADDR_IN)+16)*2)

struct MSOverlapped : OVERLAPPED {
	enum Types {
		ACCEPT_DONE,
		READ_DONE,
		WRITE_DONE,
		SHUTDOWN
	} type;
	ManagedSocketPtr ms;
	
	MSOverlapped() { memset(static_cast<OVERLAPPED*>(this), 0, sizeof(OVERLAPPED)); }
	MSOverlapped(Types type_) : type(type_) { memset(static_cast<OVERLAPPED*>(this), 0, sizeof(OVERLAPPED)); }
	MSOverlapped(Types type_, const ManagedSocketPtr& ms_) : type(type_), ms(ms_) { memset(static_cast<OVERLAPPED*>(this), 0, sizeof(OVERLAPPED)); }
};

struct ClearOverlapped {
	void operator()(MSOverlapped& overlapped) {
		overlapped.ms = 0;
	}
};

class Poller {
public:
	Poller() : handle(INVALID_HANDLE_VALUE) { 
	}
	
	~Poller() { 
		if(handle != INVALID_HANDLE_VALUE) 
			::CloseHandle(handle); 
	}
	
	bool init() {
		handle = ::CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
		return handle != NULL;
	}

	bool associate(socket_t socket) {
		return ::CreateIoCompletionPort(reinterpret_cast<HANDLE>(socket), handle, 0, 0) != FALSE;
	}
	
	bool post(MSOverlapped* overlapped) {
		return ::PostQueuedCompletionStatus(handle, 0, 0, overlapped) != FALSE;
	}
	
	bool get(DWORD* bytes, MSOverlapped** overlapped) {
		DWORD x = 0;
		return ::GetQueuedCompletionStatus(handle, bytes, &x, reinterpret_cast<OVERLAPPED**>(overlapped), WRITE_TIMEOUT);
	}
	
	operator bool() { return handle != INVALID_HANDLE_VALUE; }
private:
	HANDLE handle;
};


#elif defined(HAVE_SYS_EPOLL_H)

struct Poller {
	Poller() : poll_fd(-1) { 
	}
	
	~Poller() { 
		if(poll_fd != -1) {
			close(poll_fd);
		}
	}
	
	bool init() {
		poll_fd = epoll_create(1024);
		if(poll_fd == -1)
			return false;
		
		return true;
	}
	
	bool associate(const ManagedSocketPtr& ms) {
		struct epoll_event ev;
		ev.data.ptr = reinterpret_cast<void*>(ms.get());
		ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
		return epoll_ctl(poll_fd, EPOLL_CTL_ADD, ms->getSocket(), &ev) == 0;
	}
	
	bool associate(int fd) {
		struct epoll_event ev;
		ev.data.fd = fd;
		ev.events = EPOLLIN;
		return epoll_ctl(poll_fd, EPOLL_CTL_ADD, fd, &ev) == 0;
	}
	
	bool get(vector<epoll_event>& events) {
		events.clear();
		events.resize(1024);
		while(true) {
			int n = epoll_wait(poll_fd, &events[0], events.size(), WRITE_TIMEOUT);
			if(n == -1) {
				if(errno != EINTR) {
					return false;
				}
				// Keep looping
			} else {
				events.resize(n);
				return true;
			}
		}
	}
	
	int poll_fd;
};

#else
#error No socket implementation for your platform
#endif // _WIN32

class Writer : public Thread {
public:
	
	Writer() : stop(false) {
	}

#ifdef _WIN32
	void shutdown() {
		stop = true;
		
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::SHUTDOWN);
		
		if(!poller.post(overlapped)) {
			LOG(SocketManager::className, "Fatal error while posting shutdown to completion port: " + Util::translateError(::GetLastError()));
		}
		join();
	}
#else
	void shutdown() {
		stop = true;

		char ev = 0;
		::write(event[0], &ev, sizeof(ev));

		join();
	}
#endif	
private:
	bool init() {
		if(!poller.init()) {
			LOG(SocketManager::className, "Unable to start poller: " + Util::translateError(socket_errno));
			return false;
		}

		try {
			srv.listen(SETTING(SERVER_PORT));
			srv.setBlocking(false);
		} catch(const SocketException& e) {
			LOG(SocketManager::className, "Unable to create server socket: " + e.getError());
			return false;
		} 
		
		if(!poller.associate(srv.getSocket())) {
			LOG(SocketManager::className, "Unable to associate server socket with poller: " + Util::translateError(socket_errno));
			return false;
		}

#ifndef _WIN32
		if(socketpair(AF_UNIX, SOCK_STREAM, 0, event) == -1) {
			LOG(SocketManager::className, "Unable to create event socketpair: " + Util::translateError(errno));
			return false;
		}

		if(!poller.associate(event[1])) {
			LOG(SocketManager::className, "Unable to associate event: " + Util::translateError(errno));
			return false;
		}
#endif
		return true;
	}
	
	virtual int run() {
		LOG(SocketManager::className, "Writer starting");
		if(!init()) {
			return 0;
		}
		
		uint32_t lastWrite = 0;
		
#ifdef _WIN32
		prepareAccept();	
#endif
		while(!stop || !active.empty()) {
			handleEvents();
			
			uint32_t now = GET_TICK();
			if(now > lastWrite + WRITE_TIMEOUT) {
				writeAll();
				removeDisconnected();
				lastWrite = now;
			}

		}
		LOG(SocketManager::className, "Writer shutting down");
		return 0;
	}

#ifdef _WIN32
	void handleEvents() {
		DWORD bytes = 0;
		MSOverlapped* overlapped = 0;
		bool ret = poller.get(&bytes, &overlapped);
		//dcdebug("Event: %x, %x, %x, %x, %x, %x\n", (unsigned int)ret, (unsigned int)bytes, (unsigned int)ms, (unsigned int)overlapped, (unsigned int)overlapped->ms, (unsigned int)overlapped->type);
		
		if(!ret) {
			int error = ::GetLastError();
			if(overlapped == 0) {
				if(error != WAIT_TIMEOUT) {
					LOG(SocketManager::className, "Fatal error while getting status from completion port: " + Util::translateError(error));
					return;
				}
			} else if(overlapped->type == MSOverlapped::ACCEPT_DONE) {
				dcdebug("Error accepting: %s\n", Util::translateError(error).c_str());
				failAccept(overlapped->ms, error);
			} else if(overlapped->type == MSOverlapped::READ_DONE) {
				dcdebug("Error reading: %s\n", Util::translateError(error).c_str());
				disconnect(overlapped->ms, error);
			} else if(overlapped->type == MSOverlapped::WRITE_DONE) {
				dcdebug("Error writing: %s\n", Util::translateError(error).c_str());
				failWrite(overlapped->ms, error);
			} else {
				dcdebug("Unknown error %d when waiting\n", overlapped->type);
			}
		} else {	
			switch(overlapped->type) {
				case MSOverlapped::ACCEPT_DONE: {
					handleAccept(overlapped->ms);
					break;
				}
				case MSOverlapped::READ_DONE: {
					handleReadDone(overlapped->ms);
					break;
				}
				case MSOverlapped::WRITE_DONE: {
					handleWriteDone(overlapped->ms, bytes);
					break;
				}
				case MSOverlapped::SHUTDOWN: {
					handleShutdown();
					break;
				} 
			}
		}
		if(overlapped != 0) {
			pool.put(overlapped);
		}
	}

	void prepareAccept() throw() {
		if(stop)
			return;
		
		if(accepting.size() > PREPARED_SOCKETS / 2) {
			return;
		}
		
		while(accepting.size() < PREPARED_SOCKETS) {
			ManagedSocketPtr ms(new ManagedSocket());
			try {
				ms->create();
			} catch (const SocketException& e) {
				LOG(SocketManager::className, "Unable to create socket: " + e.getError());
				return;
			}
				
			if(!poller.associate(ms->getSocket())) {
				LOG(SocketManager::className, "Unable to associate poller: " + Util::translateError(::GetLastError()));
				return;
			}

			DWORD x = 0;

			ms->writeBuf.push_back(BufferPtr(new Buffer(ACCEPT_BUF_SIZE)));
			ms->writeBuf.back()->resize(ACCEPT_BUF_SIZE);
			
			MSOverlapped* overlapped = pool.get();
			*overlapped = MSOverlapped(MSOverlapped::ACCEPT_DONE, ms);

			if(!::AcceptEx(srv.getSocket(), ms->getSocket(), ms->writeBuf.back()->data(), 0, ACCEPT_BUF_SIZE/2, ACCEPT_BUF_SIZE/2, &x, overlapped)) {
				int error = ::WSAGetLastError();
				if(error != ERROR_IO_PENDING) {
					if(!stop) {
						LOG(SocketManager::className, "Failed accepting connection: " + Util::translateError(GetLastError()));
					}
					
					pool.put(overlapped);
					
					return;
				}
			}
			
			accepting.insert(ms);
		}
	}

	void handleAccept(const ManagedSocketPtr& ms) throw() {
		struct sockaddr_in *local, *remote;
		int sz1 = sizeof(local), sz2 = sizeof(remote);
		
		::GetAcceptExSockaddrs(ms->writeBuf.back()->data(), 0, ACCEPT_BUF_SIZE/2, ACCEPT_BUF_SIZE/2, reinterpret_cast<sockaddr**>(&local), &sz1, reinterpret_cast<sockaddr**>(&remote), &sz2);
		
		ms->setIp(inet_ntoa(remote->sin_addr));
	
		ms->writeBuf.clear();
	
		active.insert(ms);
		accepting.erase(ms);

		SocketManager::getInstance()->incomingHandler(ms);
		ms->completeAccept();
		
		read(ms);
		// Prepare a new socket to replace this one...
		prepareAccept();	
	}
	
	void failAccept(ManagedSocketPtr& ms, int error) throw() {
		accepting.erase(ms);
		
		prepareAccept();
	}

	void read(const ManagedSocketPtr& ms) throw() {
		if(stop)
			return;
			
		DWORD x = 0;
		DWORD flags = 0;
		WSABUF wsabuf = { 0, 0 };
		
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::READ_DONE, ms);
		
		if(::WSARecv(ms->getSocket(), &wsabuf, 1, &x, &flags, reinterpret_cast<LPWSAOVERLAPPED>(overlapped), 0) != 0) {
			int error = ::WSAGetLastError();
			if(error != WSA_IO_PENDING) {
				dcdebug("Error preparing read: %s\n", Util::translateError(error).c_str());
				disconnect(ms, error);
			}
		}
	}
	
	void handleReadDone(const ManagedSocketPtr& ms) throw() {
		BufferPtr readBuf(new Buffer(SETTING(BUFFER_SIZE)));
		
		WSABUF wsa = { (u_long)readBuf->size(), (char*)readBuf->data() };
		
		DWORD bytes = 0;
		DWORD flags = 0;
		
		if(::WSARecv(ms->getSocket(), &wsa, 1, &bytes, &flags, 0, 0) == SOCKET_ERROR) {
			int error = ::WSAGetLastError();
			if(error != WSAEWOULDBLOCK) {
				// Socket failed...
				disconnect(ms, error);
				return;
			}
			
			read(ms);
			return;
		}
		
		if(bytes == 0) {
			disconnect(ms, 0);
			return;
		}
		
		readBuf->resize(bytes);
		ms->completeRead(readBuf);
		
		read(ms);
	}
	
	void write(const ManagedSocketPtr& ms) throw() {
		if(stop || !(*ms) || !ms->writeBuf.empty()) {
			return;
		}
		
		ms->prepareWrite(ms->writeBuf);
		
		if(ms->writeBuf.empty()) {
			uint32_t now = GET_TICK();

			if(ms->disc || (ms->isBlocked() && ms->disc < now)) {
				disconnect(ms, 0);
			}
			return;
		}
		
		ms->wsabuf->resize(sizeof(WSABUF) * ms->writeBuf.size());
		for(size_t i = 0; i < ms->writeBuf.size(); ++i) {
			WSABUF wsa = { (u_long)ms->writeBuf[i]->size(), (char*)ms->writeBuf[i]->data() };
			memcpy(ms->wsabuf->data() + i * sizeof(WSABUF), &wsa, sizeof(WSABUF));
		}
	
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::WRITE_DONE, ms);
		
		DWORD x = 0;
		if(::WSASend(ms->getSocket(), (WSABUF*)ms->wsabuf->data(), ms->writeBuf.size(), &x, 0, reinterpret_cast<LPWSAOVERLAPPED>(overlapped), 0) != 0) {
			int error = ::WSAGetLastError();
			if(error != WSA_IO_PENDING) {
				pool.put(overlapped);
				disconnect(ms, error);
			}
		}
	}
	
	void handleWriteDone(const ManagedSocketPtr& ms, DWORD bytes) throw() {
		ms->completeWrite(ms->writeBuf, bytes);
	}
	
	void failWrite(const ManagedSocketPtr& ms, int error) throw() {
		disconnect(ms, error);
	}

	void handleShutdown() throw() {
		for(SocketSet::iterator i = accepting.begin(); i != accepting.end(); ++i) {
			(*i)->close();
		}
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			disconnect(*i, 0);
		}
	}

#else
	
	void handleEvents() {
		vector<epoll_event> events;
		if(!poller.get(events)) {
			LOG(SocketManager::className, "Poller failed: " + Util::translateError(errno));
		}
		for(vector<epoll_event>::iterator i = events.begin(); i != events.end(); ++i) {
			epoll_event& ev = *i;
			if(ev.data.fd == srv.getSocket()) {
				accept();
			} else if(ev.data.fd == event[1]) {
				handleShutdown();
			} else {
				ManagedSocketPtr ms(reinterpret_cast<ManagedSocket*>(ev.data.ptr));
				if(ev.events & (EPOLLIN | EPOLLHUP | EPOLLERR)) {
					if(!read(ms))
						continue;
				}
				if(ev.events & EPOLLOUT) {
					ms->setBlocked(false);
				}
			}
		}
	}

	void accept() {
		ManagedSocketPtr ms(new ManagedSocket());
		try {
			ms->setIp(ms->sock.accept(srv));
			ms->sock.setBlocking(false);
					
			if(!poller.associate(ms)) {
				LOG(SocketManager::className, "Unable to associate EPoll: " + Util::translateError(errno));
				return;
			}
	
			active.insert(ms);

			SocketManager::getInstance()->incomingHandler(ms);
			
			ms->completeAccept(); 
		
			read(ms);
		} catch (const SocketException& e) {
			LOG(SocketManager::className, "Unable to create socket: " + e.getError());
			return;
		}
	}
	
	bool read(const ManagedSocketPtr& ms) {
		if(stop || !(*ms))
			return false;
			
		for(;;) {
			BufferPtr buf(new Buffer(SETTING(BUFFER_SIZE)));
			
			ssize_t bytes = ::recv(ms->getSocket(), buf->data(), buf->size(), MSG_DONTWAIT);
			if(bytes == -1) {
				int error = errno;
				if(error != EAGAIN && error != EINTR) {
					ms->close();
					disconnect(ms, error);
					return false;
				}
				break;
			} else if(bytes == 0) {
				ms->close();
				disconnect(ms, 0);
				return false;
			}
			
			buf->resize(bytes);
			ms->completeRead(buf);
		}
		return true;
	}
	
	void write(const ManagedSocketPtr& ms) {
		if(stop || !(*ms)) {
			return;
		}
		BufferList buffers;
		while(true) {
			ms->prepareWrite(buffers);
			if(buffers.empty()) {
				uint32_t now = GET_TICK();
				if(ms->disc || (ms->isBlocked() && ms->disc < now)) {
					disconnect(ms, 0);
				}
				return;
			}
			std::vector<iovec> iov(buffers.size());
			for(size_t i = 0; i < buffers.size(); ++i) {
				iov[i].iov_base = buffers[i]->data();
				iov[i].iov_len = buffers[i]->size();
			}
			ssize_t bytes = ::writev(ms->getSocket(), &iov[0], iov.size());
			if(bytes == -1) {
				int error = errno;
				if(error == EAGAIN) {
					ms->completeWrite(buffers, 0);
					return;
				}
				disconnect(ms, error);
				return;
			}
			if(!ms->completeWrite(buffers, bytes)) {
				break;
			}
		}
	}

	void handleShutdown() {
		char buf;
		int bytes = ::recv(event[1], &buf, 1, MSG_DONTWAIT);
		if(bytes == -1) {
			
			int err = errno;
			if(err == EAGAIN || err == EINTR) {
				return;
			}
			LOG(SocketManager::className, "Error reading from event[1]: " + Util::translateError(err));
			return;
		}

		srv.disconnect();
		
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			disconnect(*i, 0);
		}
	}

#endif
	
	void writeAll() throw() {
		if(active.empty()) {
			return;
		}
		SocketSet::iterator start = active.begin();
		SocketSet::iterator end = active.end();
		SocketSet::iterator mid = start;
		// Start at a random position each time in order not to favorise the first sockets...
		std::advance(mid, Util::rand(active.size()));
		
		for(SocketSet::iterator i = mid; i != end; ++i) {
			write(*i);
		}
		for(SocketSet::iterator i = start; i != mid; ++i) {
			write(*i);
		}
	}
	
	void disconnect(const ManagedSocketPtr& ms, int error) {
		if(disconnecting.find(ms) != disconnecting.end()) {
			return;
		}
 
		disconnecting.insert(ms);
		
		ms->failSocket(error);
	}
	
	void removeDisconnected() {
		for(SocketSet::iterator i = disconnecting.begin(); i != disconnecting.end(); ++i) {
			(*i)->close();
			active.erase(*i);
		}
	}
	
	Poller poller;
	Socket srv;
	
	bool stop;
	
	typedef unordered_set<ManagedSocketPtr> SocketSet;
	/** Sockets that have a pending read */
	SocketSet active;
	/** Sockets that are being written to but should be disconnected if timeout it reached */
	SocketSet disconnecting;
	
#ifdef _WIN32
	Pool<MSOverlapped, ClearOverlapped> pool;
	static const size_t PREPARED_SOCKETS = 32;
	
	/** Sockets that have a pending accept */
	SocketSet accepting;
#else
	int event[2];

#endif
};
	
	
SocketManager::SocketManager() : writer(new Writer()) { 
}

SocketManager::~SocketManager() {
}

SocketManager* SocketManager::instance = 0;
const string SocketManager::className = "SocketManager";

int SocketManager::run() {
	LOG(SocketManager::className, "Starting");
	writer->start();
	writer->setThreadPriority(Thread::HIGH);
	
	ProcessQueue workQueue;

	while(true) {
		processSem.wait();
		{
			FastMutex::Lock l(processMutex);
			workQueue.swap(processQueue);
		}
		for(ProcessQueue::iterator i = workQueue.begin(); i != workQueue.end(); ++i) {
			if(!(*i)) {
				LOG(SocketManager::className, "Shutting down");
				return 0;
			}
			(*i)();
		}
		workQueue.clear();
	}
	LOG(SocketManager::className, "ERROR; should never end up here...");
	return 0;
}

void SocketManager::addJob(const Callback& callback) throw() { 
	FastMutex::Lock l(processMutex);

	processQueue.push_back(callback);
	processSem.signal(); 
}

void SocketManager::shutdown() {
	writer->shutdown();

	addJob(Callback());
	join();
	
	writer.release();
}

}
