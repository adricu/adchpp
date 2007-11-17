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

#include "LogManager.h"
#include "TimerManager.h"
#include "SocketManager.h"
#include "ClientManager.h"
#include "PluginManager.h"
#include "File.h"
#include "SettingsManager.h"

namespace adchpp {
	
const char compileTime[] = __DATE__ " " __TIME__;

void initConfig(const string& configPath) {
#ifdef _WIN32
	WSADATA wsaData;
	WSAStartup(MAKEWORD(2, 2), &wsaData);
#endif

	Util::initialize(configPath);

	ResourceManager::newInstance();
	SettingsManager::newInstance();
	LogManager::newInstance();
	TimerManager::newInstance();
	SocketManager::newInstance();
	ClientManager::newInstance();
	PluginManager::newInstance();

	SettingsManager::getInstance()->load();
}

void startup(void (*f)()) {
/*	if(!SETTING(LANGUAGE_FILE).empty()) {
		if(File::isAbsolutePath(SETTING(LANGUAGE_FILE))) {
			ResourceManager::getInstance()->loadLanguage(SETTING(LANGUAGE_FILE));
		} else {
			ResourceManager::getInstance()->loadLanguage(Util::getCfgPath() + SETTING(LANGUAGE_FILE));
		}
	}
*/
	Stats::startTime = GET_TIME();

	if(f) f();
	ClientManager::getInstance()->startup();
	SocketManager::getInstance()->startup();
	if(f) f();
	PluginManager::getInstance()->load();
}

void shutdown(void (*f)()) {
	PluginManager::getInstance()->shutdown();
	if(f) f();
	ClientManager::getInstance()->shutdown();
	if(f) f();
	SocketManager::getInstance()->shutdown();
	if(f) f();

	PluginManager::deleteInstance();
	ClientManager::deleteInstance();
	SocketManager::deleteInstance();
	LogManager::deleteInstance();
	SettingsManager::deleteInstance();
	TimerManager::deleteInstance();
	ResourceManager::deleteInstance();

#ifdef _WIN32
	WSACleanup();
#endif
}

//#ifdef _DEBUG
void logAssert(const char* file, int line, const char* exp) {
	try {
		File f(Util::getCfgPath() + _T("exceptioninfo.txt"), File::WRITE, File::OPEN | File::CREATE);
		f.setEndPos(0);
		
		f.write(string(file) + "(" + Util::toString(line) + "): " + string(exp) + "\r\n");
	} catch(const FileException& e) {
		dcdebug("logAssert: %s\n", e.getError().c_str());
	}
}
//#endif // _DEBUG

}
