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

#ifndef ADCHPP_SOCKETMANAGER_H
#define ADCHPP_SOCKETMANAGER_H

#include "common.h"

#include "forward.h"
#include "Thread.h"
#include "Mutex.h"
#include "Semaphores.h"
#include "Singleton.h"

namespace adchpp {

class SocketManager : public Singleton<SocketManager>, public Thread {
public:
	typedef std::tr1::function<void()> Callback;
	ADCHPP_DLL void addJob(const Callback& callback) throw();

	void startup() throw(ThreadException) { start(); }
	void shutdown();

	void addWriter(const ManagedSocketPtr& ms) throw();
	void addDisconnect(const ManagedSocketPtr& ms) throw();
	void addAllWriters() throw();
	
	typedef std::tr1::function<void (const ManagedSocketPtr&)> IncomingHandler;
	void setIncomingHandler(const IncomingHandler& handler) { incomingHandler = handler; }
	
private:
	friend class ManagedSocket;
	friend class Writer;
	
	virtual int run();

	typedef std::vector<Callback> ProcessQueue;

	FastMutex processMutex;
	
	ProcessQueue processQueue;

	Semaphore processSem;

	std::auto_ptr<Writer> writer;
	IncomingHandler incomingHandler;

	static const std::string className;

	friend class Singleton<SocketManager>;
	ADCHPP_DLL static SocketManager* instance;

	SocketManager();
	virtual ~SocketManager();
};

}

#endif // SOCKETMANAGER_H
