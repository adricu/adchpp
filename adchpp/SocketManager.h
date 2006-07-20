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

#ifndef SOCKETMANAGER_H
#define SOCKETMANAGER_H

#include "Thread.h"
#include "Semaphores.h"
#include "Mutex.h"

namespace adchpp {
	
class ManagedSocket;
class Writer;

/**
 * The SocketManager takes care of a set of sockets, and makes sure that data is
 * read, written and so on in a fairly correct and just fashion. All Listeners calls
 * from the SocketManager come from one thread only, and this is the thread that should 
 * be used whenever calling any of the ADCH++ functions.
 *
 * The Manager (main thread) is responsible for:
 * * Processing incoming connection message
 * * Processing line messages
 * * Processing fail message
 *
 * The Writer is responsible for:
 * * Writing data
 * * Reading data
 * * Disconnecting the socket
 * * Sending a fail message if read/write fails for some reason
 *
 */

class SocketManager : public Singleton<SocketManager>, public Thread {
public:
	typedef boost::function<void()> Callback;
	DLL void addJob(const Callback& callback) throw();

	void startup() throw(ThreadException) { start(); }
	void shutdown();

	void addWriter(ManagedSocket* ms) throw();
	void addDisconnect(ManagedSocket* ms) throw();
	void addAllWriters() throw();
	void addDeref(ManagedSocket* ms) throw();
		
private:
	friend class ManagedSocket;
	friend class Writer;
	
	virtual int run();

private:
	typedef vector<Callback> ProcessQueue;

	FastMutex processCS;
	
	ProcessQueue processQueue;
	ProcessQueue workQueue;

	Semaphore processSem;

	Writer* writer;

	static const string className;

	friend class Singleton<SocketManager>;
	static DLL SocketManager* instance;

	SocketManager();
	virtual ~SocketManager();
};

}

#endif // SOCKETMANAGER_H
