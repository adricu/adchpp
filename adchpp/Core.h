/*
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_ADCHPP_CORE_H_
#define ADCHPP_ADCHPP_CORE_H_

#include "common.h"
#include "TimeUtil.h"

#include "forward.h"

namespace adchpp {

/** A single instance of an entire hub with plugins, settings and listening sockets */
class Core {
public:
	typedef std::function<void()> Callback;
	ADCHPP_DLL ~Core();

	ADCHPP_DLL static shared_ptr<Core> create(const std::string &configPath);

	ADCHPP_DLL void run();

	ADCHPP_DLL void shutdown();

	ADCHPP_DLL LogManager &getLogManager();
	ADCHPP_DLL SocketManager &getSocketManager();
	ADCHPP_DLL PluginManager &getPluginManager();
	ADCHPP_DLL ClientManager &getClientManager();

	ADCHPP_DLL const std::string &getConfigPath() const;

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

	time::ptime getStartTime() const { return startTime; }

private:
	Core(const std::string &configPath);

	void init();

	std::unique_ptr<LogManager> lm;
	std::unique_ptr<SocketManager> sm;
	std::unique_ptr<PluginManager> pm;
	std::unique_ptr<ClientManager> cm;

	std::string configPath;
	time::ptime startTime;
};

}

#endif /* CORE_H_ */
