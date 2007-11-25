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

#include "SettingsManager.h"

#include "SimpleXML.h"
#include "File.h"
#include "LogManager.h"
#include "version.h"

namespace adchpp {
	
using namespace std;

SettingsManager* SettingsManager::instance = 0;
const string SettingsManager::className = "SettingsManager";

const string SettingsManager::settingTags[] =
{
	// Strings
	"HubName", "ServerIp", "LogFile", "Description", 
	"SENTRY", 
	// Ints
	"ServerPort", "Log", "KeepSlowUsers", 
	"MaxSendSize", "MaxBufferSize", "BufferSize", "MaxCommandSize",
	"OverflowTimeout", "DisconnectTimeout", "FloodAdd", "FloodThreshold", 
	"LoginTimeout",
	"SENTRY"
};

SettingsManager::SettingsManager() throw() {
	memset(intSettings, 0, sizeof(intSettings));
	memset(int64Settings, 0, sizeof(int64Settings));

	set(HUB_NAME, appName);
	// set(SERVER_IP, "");
	set(LOG_FILE, "logs/adchpp%Y%m.log");
	set(DESCRIPTION, versionString);
	set(SERVER_PORT, 2780);
	set(LOG, 1);
	set(KEEP_SLOW_USERS, 0);
	set(MAX_SEND_SIZE, 1400);
	set(MAX_BUFFER_SIZE, 16384);
	set(BUFFER_SIZE, 256);
	set(MAX_COMMAND_SIZE, 16384);
	set(OVERFLOW_TIMEOUT, 60*1000);
	set(DISCONNECT_TIMEOUT, 5*1000);
	set(FLOOD_ADD, 1);
	set(FLOOD_THRESHOLD, 25);
	set(LOGIN_TIMEOUT, 30);
}

bool SettingsManager::getType(const char* name, int& n, int& type) {
	for(n = 0; n < SETTINGS_LAST; n++) {
		if(strcmp(settingTags[n].c_str(), name) == 0) {
			if(n < STR_LAST) {
				type = TYPE_STRING;
				return true;
			} else if(n < INT_LAST) {
				type = TYPE_INT;
				return true;
			}
		}
	}
	return false;
}

void SettingsManager::load(const string& aFileName)
{
	try {
		SimpleXML xml;
	
		xml.fromXML(File(aFileName, File::READ, File::OPEN).read());

		xml.resetCurrentChild();
		
		xml.stepIn();
		
		if(xml.findChild("Settings")) {
			xml.stepIn();

			int i;
			string attr;

			for(i=STR_FIRST; i<STR_LAST; i++) {
				attr = settingTags[i];
				dcassert(attr.find("SENTRY") == string::npos);

				if(xml.findChild(attr))
					set(StrSetting(i), xml.getChildData());
				else
					LOGDT(className, attr + " missing from settings, using default");
				xml.resetCurrentChild();
			}
			for(i=INT_FIRST; i<INT_LAST; i++) {
				attr = settingTags[i];
				dcassert(attr.find("SENTRY") == string::npos);

				if(xml.findChild(attr))
					set(IntSetting(i), Util::toInt(xml.getChildData()));
				else
					LOGDT(className, attr + " missing from settings, using default");
				xml.resetCurrentChild();
			}
			
			xml.stepOut();

		} else {
			printf("SettingsManager: Main settings tag missing, using defaults");
		}

		signalLoad_(xml);
		
		xml.stepOut();
	
	} catch(const Exception& e) {
		printf("SettingsManager: Unable to load adchpp.xml, using defaults: %s\n", e.getError().c_str());
	}
}

}
