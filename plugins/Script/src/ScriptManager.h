/*
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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
#include <adchpp/ClientManager.h>
#include <adchpp/Plugin.h>

STANDARD_EXCEPTION(ScriptException);
class Engine;

namespace adchpp {
class SimpleXML;
class Client;
class AdcCommand;
}

class ScriptManager : public Plugin {
public:
	ScriptManager(Core &core);
	virtual ~ScriptManager();

	virtual int getVersion() { return 0; }

	void load();

	static const std::string className;
private:

	std::vector<std::unique_ptr<Engine>> engines;

	void reload();
	void clearEngines();

	ClientManager::SignalReceive::ManagedConnection reloadConn;
	ClientManager::SignalReceive::ManagedConnection statsConn;

	void onReload(Entity& c);
	void onStats(Entity& c);

	Core &core;
};

#endif //ACCESSMANAGER_H
