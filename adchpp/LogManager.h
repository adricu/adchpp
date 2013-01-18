/*
 * Copyright (C) 2006-2013 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_LOGMANAGER_H
#define ADCHPP_LOGMANAGER_H

#include "forward.h"

#include "Mutex.h"
#include "Signal.h"

namespace adchpp {
/**
 * Log writing utilities.
 */
class LogManager
{
public:
	/**
	 * Add a line to the log.
	 * @param area Name of the module that generated the error.
	 * @param msg Message to log.
	 */
	ADCHPP_DLL void log(const std::string& area, const std::string& msg) throw();

	void setLogFile(const std::string& fileName) { logFile = fileName; }
	const std::string& getLogFile() const { return logFile; }

	void setEnabled(bool enabled_) { enabled = enabled_; }
	bool getEnabled() const { return enabled; }

	typedef SignalTraits<void (const std::string&)> SignalLog;
	SignalLog::Signal& signalLog() { return signalLog_; }

private:
	friend class Core;

	FastMutex mtx;
	std::string logFile;
	bool enabled;

	LogManager(Core &core);
	
	SignalLog::Signal signalLog_;
	Core &core;

	ADCHPP_DLL void dolog(const std::string& msg) throw();
};

#define LOGC(core, area, msg) (core).getLogManager().log(area, msg)
#define LOG(area, msg) LOGC(core, area, msg)

}

#endif // LOGMANAGER_H
