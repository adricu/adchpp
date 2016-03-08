/*
 * Copyright (C) 2006-2016 Jacek Sieka, arnetheduck on gmail point com
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

#include <boost/asio/io_service.hpp>
#include <boost/asio/deadline_timer.hpp>

namespace adchpp {

struct SocketStats {
	SocketStats() : queueCalls(0), queueBytes(0), sendCalls(0), sendBytes(0), recvCalls(0), recvBytes(0) { }

	size_t queueCalls;
	int64_t queueBytes;
	size_t sendCalls;
	int64_t sendBytes;
	int64_t recvCalls;
	int64_t recvBytes;
};

class SocketManager {
public:
	typedef std::function<void()> Callback;

	/** execute a function asynchronously */
	ADCHPP_DLL void addJob(const Callback& callback) throw();
	/** execute a function after the specified amount of time
	* @param msec milliseconds
	*/
	ADCHPP_DLL void addJob(const long msec, const Callback& callback);
	/** execute a function after the specified amount of time
	* @param time a string that obeys to the "[-]h[h][:mm][:ss][.fff]" format
	*/
	ADCHPP_DLL void addJob(const std::string& time, const Callback& callback);
	/** execute a function at regular intervals
	* @param msec milliseconds
	* @return function one must call to cancel the timer (its callback will still be executed)
	*/
	ADCHPP_DLL Callback addTimedJob(const long msec, const Callback& callback);
	/** execute a function at regular intervals
	* @param time a string that obeys to the "[-]h[h][:mm][:ss][.fff]" format
	* @return function one must call to cancel the timer (its callback will still be executed)
	*/
	ADCHPP_DLL Callback addTimedJob(const std::string& time, const Callback& callback);

	void shutdown();

	void setServers(const ServerInfoList& servers_) { servers = servers_; }

	typedef std::function<void (const ManagedSocketPtr&)> IncomingHandler;
	void setIncomingHandler(const IncomingHandler& handler) { incomingHandler = handler; }

	int run();

	void setBufferSize(size_t newSize) { bufferSize = newSize; }
	size_t getBufferSize() const { return bufferSize; }

	void setMaxBufferSize(size_t newSize) { maxBufferSize = newSize; }
	size_t getMaxBufferSize() const { return maxBufferSize; }

	void setOverflowTimeout(size_t timeout) { overflowTimeout = timeout; }
	size_t getOverflowTimeout() const { return overflowTimeout; }

	void setDisconnectTimeout(size_t timeout) { disconnectTimeout = timeout; }
	size_t getDisconnectTimeout() const { return disconnectTimeout; }

	SocketStats &getStats() { return stats; }

	Core &getCore() { return core; }
private:
	friend class Core;
	friend class ManagedSocket;
	friend class SocketFactory;

	void closeFactories();

	Core &core;

	boost::asio::io_service io;
	std::unique_ptr<boost::asio::io_service::work> work;

	SocketStats stats;

	ServerInfoList servers;
	std::vector<SocketFactoryPtr> factories;

	IncomingHandler incomingHandler;

	size_t bufferSize; /// Default buffer size used for SO_RCVBUF/SO_SNDBUF
	size_t maxBufferSize; /// Max allowed write buffer size for each socket
	size_t overflowTimeout;
	size_t disconnectTimeout;

	static const std::string className;

	typedef shared_ptr<boost::asio::deadline_timer> timer_ptr;
	void addJob(const boost::asio::deadline_timer::duration_type& duration, const Callback& callback);
	Callback addTimedJob(const boost::asio::deadline_timer::duration_type& duration, const Callback& callback);
	void setTimer(timer_ptr timer, const boost::asio::deadline_timer::duration_type& duration, Callback* callback);
	void handleWait(timer_ptr timer, const boost::asio::deadline_timer::duration_type& duration, const boost::system::error_code& error,
		Callback* callback);
	void cancelTimer(timer_ptr timer, Callback* callback);

	void onLoad(const SimpleXML& xml) throw();

	SocketManager(Core &core);
};

}

#endif // SOCKETMANAGER_H
