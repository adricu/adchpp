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

#include "stdinc.h"
#include "common.h"

#include "PluginManager.h"
#include "SettingsManager.h"

#include "SimpleXML.h"
#include "LogManager.h"
#include "SocketManager.h"
#include "version.h"

#ifndef _WIN32
#include "dlfcn.h"
#endif

PluginManager* PluginManager::instance = 0;
const string PluginManager::className = "PluginManager";

PluginManager::PluginManager() throw() : pluginIds(0) { 
	SettingsManager::getInstance()->signalLoad().connect(boost::bind(&PluginManager::onLoad, this, _1));
}

PluginManager::~PluginManager() throw() { 
	
}

#include <boost/bind.hpp>

bool PluginManager::loadPlugin(const string& file) {
	if(file.length() < 3) {
		return false;
	}
	plugin_t h;

#ifndef _WIN32
	if(!Util::isAbsolutePath(file)) {
		h = PM_LOAD_LIBRARY((pluginPath + file).c_str());
	} else {
		h = PM_LOAD_LIBRARY(file.c_str());
	}
#else
	if(!Util::isAbsolutePath(file)) {
		h = LoadLibraryEx((pluginPath + file).c_str(), NULL, DONT_RESOLVE_DLL_REFERENCES);
	} else {
		h = LoadLibraryEx(file.c_str(), NULL, DONT_RESOLVE_DLL_REFERENCES);
	}
#endif

	if(h == NULL) {
		LOGDT(className, "Failed to load " + Util::toAcp(file) + ": " + PM_GET_ERROR_STRING());
		return false;
	}
	
	PLUGIN_GET_VERSION v = (PLUGIN_GET_VERSION)PM_GET_ADDRESS(h, "pluginGetVersion");
	if(v != NULL) {
		double ver = v();
		if(ver == PLUGINVERSIONFLOAT) {
#ifdef _WIN32
			// Reload plugin with references resolved...
			FreeLibrary(h);
			if(!Util::isAbsolutePath(file)) {
				h = PM_LOAD_LIBRARY((pluginPath + file).c_str());
			} else {
				h = PM_LOAD_LIBRARY(file.c_str());
			}
			if(h == NULL) {
				LOGDT(className, "Failed to load " + Util::toAcp(file) + ": " + PM_GET_ERROR_STRING());
				return false;
			}
#endif
			PLUGIN_LOAD l = (PLUGIN_LOAD)PM_GET_ADDRESS(h, "pluginLoad");
			PLUGIN_UNLOAD u = (PLUGIN_UNLOAD)PM_GET_ADDRESS(h, "pluginUnload");

			if(l != NULL && u != NULL) {
				int i = l();
				if(i != 0) {
					LOGDT(className, "Failed to load plugin " + Util::toAcp(file) + " (Error " + Util::toString(i) + ")");
				} else {
					// Wonderful, we have a plugin...
					active.push_back(PluginInfo(h, v, l, u));
					LOGDT(className, Util::toAcp(file) + " loaded");
					return true;
				}
			} else {
				LOGDT(className, Util::toAcp(file) + " is not a valid ADCH++ plugin");
			}
		} else {
			LOGDT(className, Util::toAcp(file) + " is for another version of ADCH++ (" + Util::toString(ver) + "), please get the correct one from the author");
		}
	} else {
		LOGDT(className, Util::toAcp(file) + " is not a valid ADCH++ plugin");
	}

	PM_UNLOAD_LIBRARY(h);
	return false;
}

void PluginManager::onLoad(const SimpleXML& xml) throw() {
	xml.resetCurrentChild();
	if(xml.findChild("Plugins")) {
		pluginPath = xml.getChildAttrib("Path");
		xml.stepIn();
		while(xml.findChild("Plugin")) {
			plugins.push_back(xml.getChildData() + PLUGIN_EXT);
		}
		xml.stepOut();
	}
	xml.resetCurrentChild();
}

void PluginManager::shutdown() {
	for(PluginList::reverse_iterator i = active.rbegin(); i != active.rend(); ++i)
		i->pluginUnload();
#ifndef HAVE_BROKEN_MTALLOC
	for(PluginList::reverse_iterator i = active.rbegin(); i != active.rend(); ++i)
		PM_UNLOAD_LIBRARY(i->handle);
#endif
}
