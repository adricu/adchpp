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

#include "stdinc.h"
#include "ScriptManager.h"

#include "Engine.h"
#include "LuaEngine.h"

#include <adchpp/SimpleXML.h>
#include <adchpp/File.h>
#include <adchpp/LogManager.h>
#include <adchpp/Util.h>
#include <adchpp/AdcCommand.h>
#include <adchpp/Client.h>
#include <adchpp/PluginManager.h>
#include <adchpp/Core.h>

using namespace std;
using namespace std::placeholders;

const string ScriptManager::className = "ScriptManager";

ScriptManager::ScriptManager(Core &core) : core(core) {
	LOG(className, "Starting");

	auto &pm = core.getPluginManager();
	reloadConn = manage(pm.onCommand("reload",	std::bind(&ScriptManager::onReload, this, _1)));
	statsConn = manage(pm.onCommand("stats", std::bind(&ScriptManager::onStats, this, _1)));
}

ScriptManager::~ScriptManager() {
	LOG(className, "Shutting down");
	clearEngines();
}

void ScriptManager::clearEngines() {
	engines.clear();
}

void ScriptManager::load() {
	try {
		SimpleXML xml;

		xml.fromXML(File(core.getConfigPath() + "Script.xml", File::READ).read());
		xml.stepIn();
		while(xml.findChild("Engine")) {
			const std::string& scriptPath = xml.getChildAttrib("scriptPath");
			const std::string& language = xml.getChildAttrib("language");

			if(language.empty() || language == "lua") {
				engines.push_back(std::unique_ptr<LuaEngine>(new LuaEngine(core)));
			} else {
				LOG(className, "Unrecognized language " + language);
				continue;
			}

			xml.stepIn();
			while(xml.findChild("Script")) {
				engines.back()->loadScript(scriptPath, xml.getChildData(), ParameterMap());
			}
			xml.stepOut();
		}
		xml.stepOut();
	} catch(const Exception& e) {
		LOG(className, "Failed to load settings: " + e.getError());
		return;
	}
}

void ScriptManager::reload() {
	clearEngines();
	load();
}

void ScriptManager::onReload(Entity& c) {
	core.getPluginManager().attention(std::bind(&ScriptManager::reload, this));
	c.send(AdcCommand(AdcCommand::CMD_MSG).addParam("Reloading scripts"));
}

void ScriptManager::onStats(Entity& c) {
	string tmp("Currently loaded scripts:\n");
	for(auto i = engines.begin(), iend = engines.end(); i != iend; ++i) {
		(*i)->getStats(tmp);
	}

	c.send(AdcCommand(AdcCommand::CMD_MSG).addParam(tmp));
}
