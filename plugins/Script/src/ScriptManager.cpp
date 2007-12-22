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

#include "stdinc.h"
#include "ScriptManager.h"

#include "Engine.h"
#include "LuaEngine.h"

#include <adchpp/SimpleXML.h>
#include <adchpp/File.h>
#include <adchpp/TimerManager.h>
#include <adchpp/LogManager.h>
#include <adchpp/Util.h>
#include <adchpp/SocketManager.h>
#include <adchpp/AdcCommand.h>
#include <adchpp/ClientManager.h>
#include <adchpp/Client.h>

using namespace std;
using namespace std::tr1::placeholders;

ScriptManager* ScriptManager::instance = 0;
const string ScriptManager::className = "ScriptManager";

ScriptManager::ScriptManager() {
	LOG(className, "Starting");
	ClientManager::SignalReceive::Signal& sig = ClientManager::getInstance()->signalReceive();
	receiveConn = manage(&sig, std::tr1::bind(&ScriptManager::onReceive, this, _1, _2, _3));
	
	load();
}

ScriptManager::~ScriptManager() {
	LOG(className, "Shutting down");
	clearEngines();
}

void ScriptManager::clearEngines() {
	for_each(engines.begin(), engines.end(), DeleteFunction());
	engines.clear();
}

void ScriptManager::load() {
	try {
		SimpleXML xml;
		xml.fromXML(File(Util::getCfgPath() + "Script.xml", File::READ).read());
		xml.stepIn();
		while(xml.findChild("Engine")) {
			const std::string& scriptPath = xml.getChildAttrib("scriptPath");
			const std::string& language = xml.getChildAttrib("language");
			
			if(language.empty() || language == "lua") {
				engines.push_back(new LuaEngine);
			} else {
				LOG(className, "Unrecognised language " + language);
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

void ScriptManager::onReceive(Client& c, AdcCommand& cmd, int& override) {
	
	if(cmd.getCommand() != AdcCommand::CMD_MSG) {
		return;
	}
	
	if(cmd.getParam(0) == "+reload") {
		SocketManager::getInstance()->addJob(std::tr1::bind(&ScriptManager::reload, this));
		c.send(AdcCommand(AdcCommand::CMD_MSG).addParam("Reloading scripts"));
		override |= ClientManager::DONT_SEND;
	} else if(cmd.getParam(0) == "+scripts") {
		string tmp("Currently loaded scripts:\n");
		for(vector<Engine*>::const_iterator i = engines.begin(); i != engines.end(); ++i) {
			(*i)->getStats(tmp);
		}
		c.send(AdcCommand(AdcCommand::CMD_MSG).addParam(tmp));
		override |= ClientManager::DONT_SEND;
	}
}
