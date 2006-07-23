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

#ifndef ADCHPP_SETTINGSMANAGER_H
#define ADCHPP_SETTINGSMANAGER_H

#include "Util.h"
#include "Signal.h"

namespace adchpp {

class SimpleXML;

class SettingsManager : public Singleton<SettingsManager>
{
public:
	enum Types {
		TYPE_STRING,
		TYPE_INT,
		TYPE_INT64
	};

	enum StrSetting { STR_FIRST,
		HUB_NAME = STR_FIRST, SERVER_IP, LOG_FILE, DESCRIPTION,
		LANGUAGE_FILE, REDIRECT_SERVER,
		STR_LAST };

	enum IntSetting { INT_FIRST = STR_LAST + 1,
		SERVER_PORT = INT_FIRST, LOG, MAX_USERS, KEEP_SLOW_USERS, 
		MAX_SEND_SIZE, MAX_BUFFER_SIZE, BUFFER_SIZE, MAX_COMMAND_SIZE, REDIRECT_FULL,
		OVERFLOW_TIMEOUT, DISCONNECT_TIMEOUT, FLOOD_ADD, FLOOD_THRESHOLD, 
		LOGIN_TIMEOUT,
		INT_LAST };

	enum Int64Setting { INT64_FIRST = INT_LAST + 1,
		INT64_LAST = INT64_FIRST, SETTINGS_LAST = INT64_LAST };

	/**
	 * Get the type of setting based on its name. By using the type info you can
	 * convert the n to the proper enum type and get the setting.
	 * @param name The name as seen in the settings file
	 * @param n Setting number
	 * @param type Type of setting (use this to actually get the setting later on
	 * @return True if the setting was found, false otherwise.
	 */
	ADCHPP_DLL bool getType(const char* name, int& n, int& type);
	/**
	 * Get the XML name of a setting
	 * @param n Setting identifier
	 */
	const string& getName(int n) { dcassert(n < SETTINGS_LAST); return settingTags[n]; }

	const string& get(StrSetting key) const {
		return strSettings[key - STR_FIRST];
	}

	int get(IntSetting key) const {
		return intSettings[key - INT_FIRST];
	}
	int64_t get(Int64Setting key) const {
		return int64Settings[key - INT64_FIRST];
	}

	bool getBool(IntSetting key) const {
		return (get(key) > 0);
	}

	void set(StrSetting key, string const& value) {
		strSettings[key - STR_FIRST] = value;
	}

	void set(IntSetting key, int value) {
		intSettings[key - INT_FIRST] = value;
	}

	template<typename T> void set(IntSetting key, const T& value) {
		intSettings[key - INT_FIRST] = Util::toInt(value);
	}

	void set(Int64Setting key, int64_t value) {
		int64Settings[key - INT64_FIRST] = value;
	}
	void set(Int64Setting key, int value) {
		int64Settings[key - INT64_FIRST] = value;
	}
	
	template<typename T> void set(Int64Setting key, const T& value) {
		int64Settings[key - INT64_FIRST] = Util::toInt64(value);
	}

	void set(IntSetting key, bool value) { set(key, (int)value); }

	void load() {
		load(Util::getCfgPath() + _T("adchpp.xml"));
	}

	void load(const string& aFileName);

	typedef Signal<void (const SimpleXML&)> SignalLoad;
	SignalLoad& signalLoad() { return signalLoad_; }
private:
	friend class Singleton<SettingsManager>;
	ADCHPP_DLL static SettingsManager* instance;
	
	SettingsManager() throw();
	virtual ~SettingsManager() throw() { }

	static const string settingTags[SETTINGS_LAST+1];

	static const string className;

	string strSettings[STR_LAST - STR_FIRST];
	int    intSettings[INT_LAST - INT_FIRST];
	int64_t int64Settings[/*INT64_LAST - INT64_FIRST*/1];
	
	SignalLoad signalLoad_;
};


// Shorthand accessor macros
#define SETTING(k) (SettingsManager::getInstance()->get(SettingsManager::k))
#define BOOLSETTING(k) (SettingsManager::getInstance()->getBool(SettingsManager::k))

}

#endif // SETTINGSMANAGER_H
