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

#ifndef SCRIPT_MANAGER_H
#define SCRIPT_MANAGER_H

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <adchpp/Exception.h>
#include <adchpp/Singleton.h>
#include <adchpp/ClientManager.h>

#ifdef _WIN32
# ifdef ACCESS_EXPORT
#  define SCRIPT_DLL __declspec(dllexport)
# else
#  define SCRIPT_DLL __declspec(dllimport)
# endif
#else
# define SCRIPT_DLL
#endif

STANDARD_EXCEPTION(ScriptException);
class Engine;

namespace adchpp {
class SimpleXML;
class Client;
class AdcCommand;
}

class ScriptManager : public Singleton<ScriptManager> {
public:
	ScriptManager();
	virtual ~ScriptManager();

	virtual int getVersion() { return 0; }

	static const string className;
private:
	friend class Singleton<ScriptManager>;
	static ScriptManager* instance;
	
	vector<Engine*> engines;
	
	void load();
	void reload();
	void clearEngines();
	
	ClientManager::SignalReceive::ManagedConnection receiveConn;
	void onReceive(Client& c, AdcCommand& cmd, int& handled);
};

#endif //ACCESSMANAGER_H
