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

#ifndef ADCHPP_SOCKETMANAGER_H
#define ADCHPP_SOCKETMANAGER_H

#include "common.h"

#include "forward.h"
#include "ServerInfo.h"
#include "Singleton.h"
#include "Util.h"

#include <boost/asio.hpp>

namespace adchpp {

class SocketManager : public Singleton<SocketManager>, public Thread {
public:
	typedef std::tr1::function<void()> Callback;
	ADCHPP_DLL void addJob(const Callback& callback) throw();
	/** execute a function after the specified amount of time
	* @param usec microseconds
	*/
	ADCHPP_DLL void addJob(const long usec, const Callback& callback);
	/** execute a function after the specified amount of time
	* @param time a string that obeys to the "[-]h[h][:mm][:ss][.fff]" format
	*/
	ADCHPP_DLL void addJob(const std::string& time, const Callback& callback);

	void startup() throw(ThreadException);
	void shutdown();

	void setServers(const ServerInfoList& servers_) { servers = servers_; }

	typedef std::tr1::function<void (const ManagedSocketPtr&)> IncomingHandler;
	void setIncomingHandler(const IncomingHandler& handler) { incomingHandler = handler; }

	std::map<std::string, int> errors;

private:
	friend class ManagedSocket;
	friend class SocketFactory;

	virtual int run();

	void closeFactories();

	boost::asio::io_service io;
	std::auto_ptr<boost::asio::io_service::work> work;

	ServerInfoList servers;
	std::vector<SocketFactoryPtr> factories;

	IncomingHandler incomingHandler;

	static const std::string className;

	friend class Singleton<SocketManager>;
	ADCHPP_DLL static SocketManager* instance;

	typedef std::tr1::shared_ptr<boost::asio::deadline_timer> timer_ptr;
	void addJob(const boost::asio::deadline_timer::duration_type& duration, const Callback& callback);
	void handleWait(timer_ptr timer, const boost::system::error_code& error, Callback* callback);

	void onLoad(const SimpleXML& xml) throw();

	SocketManager();
	virtual ~SocketManager();
};

}

#endif // SOCKETMANAGER_H
