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

#include "adchpp.h"

#include "SocketManager.h"

#include "LogManager.h"
#include "TimerManager.h"
#include "ClientManager.h"
#include "SettingsManager.h"
#include "Semaphores.h"
#include "ManagedSocket.h"
#include "Thread.h"

#include <boost/bind.hpp>

#ifdef _WIN32
#include <MSWSock.h>
#endif

#ifdef HAVE_SYS_EPOLL_H
#include <sys/epoll.h>
#endif

namespace adchpp {
static uint32_t WRITE_TIMEOUT = 100;

#ifdef _WIN32

#define ACCEPT_BUF_SIZE ((sizeof(SOCKADDR_IN)+16)*2)

struct MSOverlapped : OVERLAPPED {
	enum Types {
		ACCEPT,
		READ_DONE,
		WRITE_DONE,
		WRITE_WAITING,
		WRITE_ALL,
		DISCONNECT,
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

class CompletionPort {
public:
	CompletionPort() : handle(INVALID_HANDLE_VALUE) { 
	}
	
	~CompletionPort() { 
		if(handle != INVALID_HANDLE_VALUE) 
			::CloseHandle(handle); 
	}
	
	bool create() {
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

class Writer : public Thread {
public:
	static const size_t PREPARED_SOCKETS = 32;
	
	Writer() : stop(false) {
	}
	
	void addWriter(ManagedSocketPtr /*ms */) {
		if(stop)
			return;
#if 0
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::WRITE_WAITING, ms);
		
		if(!port.post(overlapped)) {
			LOGDT(SocketManager::className, "Fatal error while posting write to completion port: " + Util::translateError(::GetLastError()));
		}
#endif			
	}
	
	void addAllWriters() {
		if(stop)
			return;
#if 0			
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::WRITE_ALL);
		
		if(!port.post(overlapped)) {
			LOGDT(SocketManager::className, "Fatal error while posting writeAll to completion port: " + Util::translateError(::GetLastError()));
		}
#endif			
	}
	
	void addDisconnect(ManagedSocketPtr ms) {
		if(stop)
			return;
			
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::DISCONNECT, ms);
		
		if(!port.post(overlapped)) {
			LOGDT(SocketManager::className, "Fatal error while posting disconnect to completion port: " + Util::translateError(::GetLastError()));
		}			
	}			
	
	void shutdown() {
		stop = true;
		
		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::SHUTDOWN);
		
		if(!port.post(overlapped)) {
			LOGDT(SocketManager::className, "Fatal error while posting shutdown to completion port: " + Util::translateError(::GetLastError()));
		}
		join();
	}

	void getErrors(SocketManager::ErrorMap& acceptErrors_, SocketManager::ErrorMap& readErrors_, SocketManager::ErrorMap& writeErrors_) {
		FastMutex::Lock l(errorMutex);
		acceptErrors_ = acceptErrors;
		readErrors_ = readErrors;
		writeErrors_ = writeErrors;
	}
	
private:
	bool init() {
		if(!port.create()) {
			LOGDT(SocketManager::className, "Unable to create IO Completion port: " + Util::translateError(::GetLastError()));
			return false;
		}

		try {
			srv.listen(static_cast<short>(SETTING(SERVER_PORT)));
		} catch(const SocketException& e) {
			LOGDT(SocketManager::className, "Unable to create server socket: " + e.getError());
			return false;
		} 
		
		if(!port.associate(srv.getSocket())) {
			LOGDT(SocketManager::className, "Unable to associate IO Completion port: " + Util::translateError(::GetLastError()));
			return false;
		}
	
		return true;
	}
	
	virtual int run() {
		LOGDT(SocketManager::className, "Writer starting");
		if(!init()) {
			return 0;
		}
		
		prepareAccept();
		
		DWORD bytes = 0;
		MSOverlapped* overlapped = 0;
		
		uint32_t lastWrite = 0;
		
		while(!stop || !accepting.empty() || !active.empty()) {
			bool ret = port.get(&bytes, &overlapped);
			//dcdebug("Event: %x, %x, %x, %x, %x, %x\n", (unsigned int)ret, (unsigned int)bytes, (unsigned int)ms, (unsigned int)overlapped, (unsigned int)overlapped->ms, (unsigned int)overlapped->type);
			
			if(!ret) {
				int error = ::GetLastError();
				if(overlapped == 0) {
					if(error != WAIT_TIMEOUT) {
						LOGDT(SocketManager::className, "Fatal error while getting status from completion port: " + Util::translateError(error));
						return error;
					}
				} else if(overlapped->type == MSOverlapped::ACCEPT) {
					dcdebug("Error accepting: %s\n", Util::translateError(error).c_str());
					failAccept(overlapped->ms, error);
				} else if(overlapped->type == MSOverlapped::READ_DONE) {
					dcdebug("Error reading: %s\n", Util::translateError(error).c_str());
					failRead(overlapped->ms, error);
				} else if(overlapped->type == MSOverlapped::WRITE_DONE) {
					dcdebug("Error writing: %s\n", Util::translateError(error).c_str());
					failWrite(overlapped->ms, error);
				} else {
					dcdebug("Unknown error %d when waiting\n", overlapped->type);
				}
			} else {	
				switch(overlapped->type) {
					case MSOverlapped::ACCEPT: {
						checkDisconnects();
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
					case MSOverlapped::WRITE_WAITING: {
						prepareWrite(overlapped->ms);
						break;
					}
					case MSOverlapped::WRITE_ALL: {
						writeAll();
						break;
					}
					case MSOverlapped::DISCONNECT: {
						handleDisconnect(overlapped->ms);
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
			
			uint32_t now = GET_TICK();
			if(now > lastWrite + WRITE_TIMEOUT) {
				checkDisconnects();
				writeAll();
				lastWrite = now;
			}

		}
		LOGDT(SocketManager::className, "Writer shutting down");
		return 0;
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
				LOGDT(SocketManager::className, "Unable to create socket: " + e.getError());
				return;
			}
				
			if(!port.associate(ms->getSocket())) {
				LOGDT(SocketManager::className, "Unable to associate IO Completion port: " + Util::translateError(::GetLastError()));
				return;
			}

			DWORD x = 0;

			ms->writeBuf = Util::freeBuf;
			ms->writeBuf->resize(ACCEPT_BUF_SIZE);
			
			MSOverlapped* overlapped = pool.get();
			*overlapped = MSOverlapped(MSOverlapped::ACCEPT, ms);

			if(!::AcceptEx(srv.getSocket(), ms->getSocket(), &(*ms->writeBuf)[0], 0, ACCEPT_BUF_SIZE/2, ACCEPT_BUF_SIZE/2, &x, overlapped)) {
				int error = ::WSAGetLastError();
				if(error != ERROR_IO_PENDING) {
					if(!stop) {
						LOGDT(SocketManager::className, "Failed accepting connection: " + Util::translateError(GetLastError()));
					}
					
					pool.put(overlapped);
					
					FastMutex::Lock l(errorMutex);
					acceptErrors[error]++;
					
					return;
				}
			}
			
			accepting.insert(ms);
		}
	}

	void handleAccept(const ManagedSocketPtr& ms) throw() {
		struct sockaddr_in *local, *remote;
		int sz1 = sizeof(local), sz2 = sizeof(remote);
		
		::GetAcceptExSockaddrs(&(*ms->writeBuf)[0], 0, ACCEPT_BUF_SIZE/2, ACCEPT_BUF_SIZE/2, reinterpret_cast<sockaddr**>(&local), &sz1, reinterpret_cast<sockaddr**>(&remote), &sz2);
		
		ms->setIp(inet_ntoa(remote->sin_addr));
	
		Util::freeBuf = ms->writeBuf;
		ms->writeBuf = 0;
	
		active.insert(ms);
		accepting.erase(ms);

		ClientManager::getInstance()->incomingConnection(ms);

		ms->completeAccept();
		
		prepareRead(ms);
		// Prepare a new socket to replace this one...
		prepareAccept();	
	}
	
	void failAccept(ManagedSocketPtr& ms, int error) throw() {
		accepting.erase(ms);
		
		
		prepareAccept();
		
		FastMutex::Lock l(errorMutex);
		acceptErrors[error]++;
	}
	
	void prepareRead(const ManagedSocketPtr& ms) throw() {
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
				failRead(ms, error);
			}
		}
	}
	
	void handleReadDone(const ManagedSocketPtr& ms) throw() {
		ByteVector* readBuf = Util::freeBuf;
		
		if(readBuf->size() < (size_t)SETTING(BUFFER_SIZE))
			readBuf->resize(SETTING(BUFFER_SIZE));
		
		WSABUF wsa = { (u_long)readBuf->size(), (char*)&(*readBuf)[0] };
		
		DWORD bytes = 0;
		DWORD flags = 0;
		
		if(::WSARecv(ms->getSocket(), &wsa, 1, &bytes, &flags, 0, 0) == SOCKET_ERROR) {
			Util::freeBuf = readBuf;
			int error = ::WSAGetLastError();
			if(error != WSAEWOULDBLOCK) {
				// Socket failed...
				failRead(ms, error);
				return;
			}
			
			prepareRead(ms);
			return;
		}
		
		if(bytes == 0) {
			Util::freeBuf = readBuf;
			failRead(ms, 0);
			return;
		}
		
		readBuf->resize(bytes);
		ms->completeRead(readBuf);
		
		prepareRead(ms);
	}
	
	void failRead(const ManagedSocketPtr& ms, int error) throw() {
		if(active.find(ms) == active.end()) {
			return;
		}
		
		if(error != 0) {
			FastMutex::Lock l(errorMutex);
			readErrors[error]++;
		}
		 
		ms->close();

		SocketSet::iterator i = disconnecting.find(ms);
		if(i == disconnecting.end()) {
			ms->failSocket();
		} else {
			disconnecting.erase(i);
		}
			
		active.erase(ms);
	}
	
	void prepareWrite(const ManagedSocketPtr& ms) throw() {
		if(stop || ms->writeBuf) {
			return;
		}
		
		ms->writeBuf = ms->prepareWrite();
		
		if(!ms->writeBuf) {
			if(ms->disc) {
				ms->close();
			}
			return;
		}
		
		ms->wsabuf.len = ms->writeBuf->size();
		ms->wsabuf.buf = reinterpret_cast<char*>(&(*ms->writeBuf)[0]);

		MSOverlapped* overlapped = pool.get();
		*overlapped = MSOverlapped(MSOverlapped::WRITE_DONE, ms);
		
		DWORD x = 0;
		if(::WSASend(ms->getSocket(), &ms->wsabuf, 1, &x, 0, reinterpret_cast<LPWSAOVERLAPPED>(overlapped), 0) != 0) {
			int error = ::WSAGetLastError();
			if(error != WSA_IO_PENDING) {
				failWrite(ms, error);
				pool.put(overlapped);
			}
		}
		return;
	}
	
	void handleWriteDone(const ManagedSocketPtr& ms, DWORD bytes) throw() {
		ByteVector* buf = ms->writeBuf;
		ms->writeBuf = 0;
		
		if(!buf) {
			dcdebug("No buffer in handleWriteDone??\n");
			return;
		}
		if(ms->completeWrite(buf, bytes)) {
			prepareWrite(ms);
		}
	}
	
	void failWrite(const ManagedSocketPtr& ms, int error) throw() {
		Util::freeBuf = ms->writeBuf;
		ms->writeBuf = 0;
		
		FastMutex::Lock l(errorMutex);
		writeErrors[error]++;
	}
	
	void writeAll() throw() {
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			prepareWrite(*i);
		}
	}
	
	void handleDisconnect(const ManagedSocketPtr& ms) throw() {
		if(active.find(ms) == active.end()) {
			return;
		}
		
		if(disconnecting.find(ms) != disconnecting.end()) {
			return;
		}
 
		prepareWrite(ms);
		disconnecting.insert(ms);
		ms->failSocket();
	}
	
	void checkDisconnects() throw() {
		uint32_t now = GET_TICK();
		for(SocketSet::iterator i = disconnecting.begin(); i != disconnecting.end(); ++i) {
			const ManagedSocketPtr& ms = *i;
			if(ms->disc + (uint32_t)SETTING(DISCONNECT_TIMEOUT) < now) {
				ms->close();
			}
		}
	}
	
	void handleShutdown() throw() {
		for(SocketSet::iterator i = accepting.begin(); i != accepting.end(); ++i) {
			(*i)->close();
		}
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			(*i)->close();
		}
	}
	
	FastMutex errorMutex;
	SocketManager::ErrorMap acceptErrors;
	SocketManager::ErrorMap readErrors;
	SocketManager::ErrorMap writeErrors;
	
	CompletionPort port;
	Socket srv;
	
	bool stop;
	
	Pool<MSOverlapped, ClearOverlapped> pool;
	
	typedef HASH_SET<ManagedSocketPtr, PointerHash<ManagedSocket> > SocketSet;
	/** Sockets that have a pending read */
	SocketSet active;
	/** Sockets that have a pending accept */
	SocketSet accepting;
	/** Sockets that are being written to but should be disconnected if timeout it reached */
	SocketSet disconnecting;
};

#elif defined(HAVE_SYS_EPOLL_H)

struct EPoll {
	EPoll() : poll_fd(-1) { 
	}
	
	~EPoll() { 
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
		events.resize(1024);
		int n = epoll_wait(poll_fd, &events[0], events.size(), WRITE_TIMEOUT);
		if(n == -1) {
			return false;
		}
		events.resize(n);
		return true;
	}
	
	int poll_fd;
};

struct Event {
	enum Type {
		WRITE,
		WRITE_ALL,
		DISCONNECT,
		REMOVE,
		SHUTDOWN
	} event;
	ManagedSocketPtr ms;
	
	Event(Type event_, const ManagedSocketPtr& ms_) : event(event_), ms(ms_) { }
	Event() : event(WRITE), ms(0) { }
};

struct ClearEvent {
	void operator()(Event& evt) {
		evt.ms = 0;
	}
};

class Writer : public Thread {
public:
	Writer() : stop(false) {
	}
	
	void addWriter(const ManagedSocketPtr& ms) {
		if(stop)
			return;
/*		
		Event* ev = pool.get();
		*ev = Event(Event::WRITE, ms);
		::write(event[0], &ev, sizeof(ev));*/
	}
	
	void addAllWriters() {
		if(stop)
			return;
/*		Event* ev = pool.get();
		*ev = Event(Event::WRITE_ALL, 0);
		::write(event[0], &ev, sizeof(ev));*/
	}
	
	void addDisconnect(const ManagedSocketPtr& ms) {
		if(stop)
			return;
			
		Event* ev = pool.get();
		*ev = Event(Event::DISCONNECT, ms);
		::write(event[0], &ev, sizeof(ev));
	}			
	
	void shutdown() {
		stop = true;

		Event* ev = pool.get();
		*ev = Event(Event::SHUTDOWN, 0);
		::write(event[0], &ev, sizeof(ev));

		join();
	}
	
	void getErrors(SocketManager::ErrorMap& acceptErrors_, SocketManager::ErrorMap& readErrors_, SocketManager::ErrorMap& writeErrors_) {
		FastMutex::Lock l(errorMutex);
		acceptErrors_ = acceptErrors;
		readErrors_ = readErrors;
		writeErrors_ = writeErrors;
	}
	
private:
	bool init() {
		if(!poller.init()) {
			LOGDT(SocketManager::className, "Unable to create initialize epoll: " + Util::translateError(errno));
			return false;
		}			
		
		try {
			srv.listen(SETTING(SERVER_PORT));
			srv.setBlocking(false);
		} catch(const SocketException& e) {
			LOGDT(SocketManager::className, "Unable to create server socket: " + e.getError());
			return false;
		} 
		
		if(!poller.associate(srv.getSocket())) {
			LOGDT(SocketManager::className, "Unable to set epoll: " + Util::translateError(errno));
			return false;
		}
		
		if(socketpair(AF_UNIX, SOCK_STREAM, 0, event) == -1) {
			LOGDT(SocketManager::className, "Unable to create event socketpair: " + Util::translateError(errno));
			return false;
		}
		if(!poller.associate(event[1])) {
			LOGDT(SocketManager::className, "Unable to associate event: " + Util::translateError(errno));
			return false;
		}
		return true;
	}
	
	virtual int run() {
		LOGDT(SocketManager::className, "Writer starting");
		if(!init()) {
			return 0;
		}
		
		uint32_t lastWrite = 0;
		std::vector<epoll_event> events;
		while(!stop || !active.empty()) {
			events.clear();
			
			if(!poller.get(events)) {
				LOGDT(SocketManager::className, "Poller failed: " + Util::translateError(errno));
			}
			for(std::vector<epoll_event>::iterator i = events.begin(); i != events.end(); ++i) {
				epoll_event& ev = *i;
				if(ev.data.fd == srv.getSocket()) {
					accept();
				} else if(ev.data.fd == event[1]) {
					handleEvents();
				} else {
					ManagedSocketPtr ms(reinterpret_cast<ManagedSocket*>(ev.data.ptr));
					if(ev.events & EPOLLOUT) {
						write(ms);
					}
					if(ev.events & (EPOLLIN | EPOLLHUP | EPOLLERR)) {
						read(ms);
					} 
				}
			}
			
			uint32_t now = GET_TICK();
			if(now > lastWrite + WRITE_TIMEOUT) {
				checkDisconnects();
				writeAll();
				lastWrite = now;
			}
		}
		LOGDT(SocketManager::className, "Writer shutting down");
		return 0;
	}
	
	void handleEvents() {
		while(true) {
			size_t start = ev.size();
			ev.resize(64 * sizeof(Event*));
			int bytes = ::recv(event[1], &ev[0] + start, ev.size() - start, MSG_DONTWAIT);
			if(bytes == -1) {
				ev.resize(start);
				int err = errno;
				if(err == EAGAIN) {
					return;
				}
				LOGDT(SocketManager::className, "Error reading from event[1]: " + Util::translateError(err));
				return;
			}
			ev.resize(bytes);
			size_t events = bytes / sizeof(Event*);
			for(size_t i = 0; i < events; ++i) {
				Event** ee = reinterpret_cast<Event**>(&ev[i*sizeof(Event*)]);
				Event* e = *ee;
				switch(e->event) {
					case Event::WRITE: {
						write(e->ms);
					} break;
					case Event::WRITE_ALL: {
						writeAll();
					} break;
					case Event::DISCONNECT: {
						disconnect(e->ms);
					} break;
					case Event::REMOVE: {
						failRead(e->ms, 0);
					} break;
					case Event::SHUTDOWN: {
						handleShutdown();
					} break;
				}
				pool.put(e);
			}
			ev.erase(ev.begin(), ev.begin() + events*sizeof(Event*));
		}	
	}
	
	void accept() throw() {
		ManagedSocketPtr ms(new ManagedSocket());
		try {
			ms->setIp(ms->sock.accept(srv));
					
			if(!poller.associate(ms)) {
				LOGDT(SocketManager::className, "Unable to associate EPoll: " + Util::translateError(errno));
				return;
			}
	
			active.insert(ms);

			ClientManager::getInstance()->incomingConnection(ms);
			
			ms->completeAccept(); 
		
			read(ms);
		} catch (const SocketException& e) {
			LOGDT(SocketManager::className, "Unable to create socket: " + e.getError());
			if(e.getErrorCode() != 0) {
				FastMutex::Lock l(errorMutex);
				acceptErrors[e.getErrorCode()]++;
			}
			return;
		}
	}
	
	void read(const ManagedSocketPtr& ms) throw() {
		if(stop)
			return;
		bool cont = true;
		while(cont) {
			ByteVector* readBuf = Util::freeBuf;
			if(readBuf->size() < (size_t)SETTING(BUFFER_SIZE))
				readBuf->resize(SETTING(BUFFER_SIZE));
				
			ssize_t bytes = ::recv(ms->getSocket(), &(*readBuf)[0], readBuf->size(), MSG_DONTWAIT);
			if(bytes == -1) {
				Util::freeBuf = readBuf;
				
				int error = errno;
				if(error != EAGAIN) {
					failRead(ms, error);
				}
				return;
			} else if(bytes == 0) {
				Util::freeBuf = readBuf;
				failRead(ms, 0);
				return;
			}
			cont = (readBuf->size() == static_cast<size_t>(bytes));
			
			readBuf->resize(bytes);
			ms->completeRead(readBuf);
		}
	}
	
	void failRead(const ManagedSocketPtr& ms, int error) throw() {
		if(active.find(ms) == active.end()) {
			return;
		}
		
		ms->close();
		SocketSet::iterator i = disconnecting.find(ms);
		if(i == disconnecting.end()) {
			ms->failSocket();
		} else {
			disconnecting.erase(i);
		}
		
		active.erase(ms);
		if(error != 0) {
			FastMutex::Lock l(errorMutex);
			readErrors[error]++;
		}
	}
	
	void write(const ManagedSocketPtr& ms) throw() {
		if(stop) {
			return;
		}
		
		while(true) {
			ByteVector* writeBuf = ms->prepareWrite();
			
			if(!writeBuf) {
				if(ms->disc) {
					addRemove(ms);
				}
				return;
			}
			
			ssize_t bytes = ::send(ms->getSocket(), &(*writeBuf)[0], writeBuf->size(), MSG_NOSIGNAL | MSG_DONTWAIT);
			if(bytes == -1) {
				int error = errno;
				if(error == EAGAIN) {
					ms->completeWrite(writeBuf, 0);
					return;
				}
				Util::freeBuf = writeBuf;
				failWrite(ms, error);
				return;
			}
			if(!ms->completeWrite(writeBuf, bytes)) {
				break;
			}
		}
	}
	
	void failWrite(const ManagedSocketPtr& ms, int error) throw() {
		addRemove(ms);
		if(error != 0) {
			FastMutex::Lock l(errorMutex);
			writeErrors[error]++;
		}
	}
	
	void writeAll() throw() {
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			write(*i);
		}
	}
	
	void disconnect(const ManagedSocketPtr& ms) throw() {
		if(active.find(ms) == active.end()) 
			return;
		
		if(disconnecting.find(ms) != disconnecting.end()) {
			return;
		}

		disconnecting.insert(ms);
		ms->failSocket();
		write(ms);
	}
	
	void checkDisconnects() throw() {
		uint32_t now = GET_TICK();
		for(SocketSet::iterator i = disconnecting.begin(); i != disconnecting.end(); ++i) {
			const ManagedSocketPtr& ms = *i;
			if(ms->disc + (uint32_t)SETTING(DISCONNECT_TIMEOUT) < now) {
				ms->shutdown();
			}
		}
	}
	
	void handleShutdown() throw() {
		srv.disconnect();
		
		for(SocketSet::iterator i = active.begin(); i != active.end(); ++i) {
			addRemove(*i);
		}
	}
	
	// This is needed because calling close() on the socket
	// will remove it from the epoll set (so the main loop won't
	// be notified)
	void addRemove(const ManagedSocketPtr& ms) {
		Event* ev = pool.get();
		*ev = Event(Event::REMOVE, ms);
		::write(event[0], &ev, sizeof(ev));
	}
		
	EPoll poller;
	Socket srv;
	
	FastMutex errorMutex;
	SocketManager::ErrorMap acceptErrors;
	SocketManager::ErrorMap readErrors;
	SocketManager::ErrorMap writeErrors;

	bool stop;

	int event[2];
	std::vector<uint8_t> ev;
	
	Pool<Event, ClearEvent> pool;
		
	typedef HASH_SET<ManagedSocketPtr, PointerHash<ManagedSocket> > SocketSet;
	/** Sockets that have a pending read */
	SocketSet active;
	/** Sockets that are being written to but should be disconnected if timeout it reached */
	SocketSet disconnecting;
};

#else
#error No socket implementation for your platform
#endif // _WIN32
	
SocketManager::SocketManager() : writer(new Writer()) { 
}

SocketManager::~SocketManager() {
}

SocketManager* SocketManager::instance = 0;
const string SocketManager::className = "SocketManager";

int SocketManager::run() {
	LOGDT(SocketManager::className, "Starting");
	writer->start();
	writer->setThreadPriority(Thread::HIGH);
	
	while(true) {
		processSem.wait();
		{
			FastMutex::Lock l(processCS);
			workQueue.swap(processQueue);
		}
		for(ProcessQueue::iterator i = workQueue.begin(); i != workQueue.end(); ++i) {
			if(!(*i)) {
				LOGDT(SocketManager::className, "Shutting down");
				return 0;
			}
			(*i)();
		}
		workQueue.clear();
	}
	LOGDT(SocketManager::className, "ERROR; should never end up here...");
	return 0;
}

void SocketManager::addWriter(const ManagedSocketPtr& ms) throw() {
	writer->addWriter(ms);
}

void SocketManager::addAllWriters() throw() {
	writer->addAllWriters();	
}

void SocketManager::addDisconnect(const ManagedSocketPtr& ms) throw() {
	writer->addDisconnect(ms);
}

void SocketManager::addJob(const Callback& callback) throw() { 
	FastMutex::Lock l(processCS);

	processQueue.push_back(callback);
	processSem.signal(); 
}

void SocketManager::shutdown() {
	writer->shutdown();

	addJob(Callback());
	join();
	
	writer.release();
}

void SocketManager::getErrors(ErrorMap& acceptErrors_, ErrorMap& readErrors_, ErrorMap& writeErrors_) {
	writer->getErrors(acceptErrors_, readErrors_, writeErrors_);
}


}
