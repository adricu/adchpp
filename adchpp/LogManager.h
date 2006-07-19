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

#ifndef LOGMANAGER_H
#define LOGMANAGER_H

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "CriticalSection.h"

/**
 * Log writing utilities.
 */
class LogManager : public Singleton<LogManager>
{
public:
	/**
	 * Add a line to the log. 
	 * @param area Name of the module that generated the error.
	 * @param msg Message to log.
	 */
	void log(const string& area, const string& msg) throw() {
		string tmp(area);
		tmp += ": ";
		tmp += msg;
		dolog(tmp);
	}
	
	/**
	 * Same as log, but prepends the current date and time.
	 * @see log
	 */	 
	DLL void logDateTime(const string& area, const string& msg) throw();
private:
	friend class Singleton<LogManager>;
	static DLL LogManager* instance;
	FastCriticalSection cs;

	LogManager() throw() { }
	virtual ~LogManager() throw() { }
	
	DLL void dolog(const string& msg) throw();
};

#define LOG(area, msg) LogManager::getInstance()->log(area, msg)
#define LOGDT(area, msg) LogManager::getInstance()->logDateTime(area, msg)

#endif // LOGMANAGER_H
