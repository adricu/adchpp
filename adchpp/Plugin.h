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
#ifndef ADCHPP_PLUGIN_H_
#define ADCHPP_PLUGIN_H_

#include "forward.h"

namespace adchpp {

/**
 * Public plugin interface, for plugin intercom.
 * Plugins that register a public interface must inherit from this class.
 * Plugins requesting another plugins interface will get a pointer to this
 * class and must upcast it (using dynamic_cast<> and check NULL to be safe).
 */
class Plugin {
public:
	Plugin() { }
	virtual ~Plugin() { }
	/** @return API version for a plugin (incremented every time API changes) */
	virtual int getVersion() = 0;
};

typedef std::function<void (void*)> PluginDataDeleter;

class PluginData {
public:
	template<typename T>
	static void simpleDataDeleter(void* p) { delete reinterpret_cast<T*>(p); }
private:
	friend class PluginManager;
	friend class Entity;

	PluginData(const PluginDataDeleter& deleter_) : deleter(deleter_) { }

	void operator()(void* p) { if(deleter) deleter(p); }

	PluginDataDeleter deleter;
};

typedef shared_ptr<PluginData> PluginDataHandle;

}

#endif /* PLUGIN_H_ */
