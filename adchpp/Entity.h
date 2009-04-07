/*
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_ENTITY_H
#define ADCHPP_ENTITY_H

#include "forward.h"
#include "Buffer.h"
#include "AdcCommand.h"
#include "Plugin.h"

namespace adchpp {

class ADCHPP_VISIBLE Entity {
public:
	Entity(uint32_t sid_) : sid(sid_) {

	}

	void send(const AdcCommand& cmd) { send(cmd.getBuffer()); }
	virtual void send(const BufferPtr& cmd) = 0;

	ADCHPP_DLL const std::string& getField(const char* name) const;
	ADCHPP_DLL bool hasField(const char* name) const;
	ADCHPP_DLL void setField(const char* name, const std::string& value);

	/** Add any flags that have been updated to the AdcCommand (type etc is not set) */
	ADCHPP_DLL bool getAllFields(AdcCommand& cmd) const throw();
	ADCHPP_DLL const BufferPtr& getINF() const;

	ADCHPP_DLL bool addSupports(uint32_t feature);
	ADCHPP_DLL StringList getSupportList() const;
	ADCHPP_DLL bool hasSupport(uint32_t feature) const;
	ADCHPP_DLL bool removeSupports(uint32_t feature);

	ADCHPP_DLL const BufferPtr& getSUP() const;

	uint32_t getSID() const { return sid; }

	ADCHPP_DLL bool isFiltered(const std::string& features) const;

	ADCHPP_DLL void updateFields(const AdcCommand& cmd);
	ADCHPP_DLL void updateSupports(const AdcCommand& cmd) throw();

	/**
	 * Set PSD (plugin specific data). This allows a plugin to store arbitrary
	 * per-client data, and retrieve it later on. The life cycle of the data follows
	 * that of the client unless explicitly removed. Any data referenced by the plugin
	 * will have its delete function called when the Entity is deleted.
	 * @param id Id as retrieved from PluginManager::getPluginId()
	 * @param data Data to store, this can be pretty much anything
	 */
	ADCHPP_DLL void setPluginData(const PluginDataHandle& handle, void* data) throw();

	/**
	 * @param handle Plugin data handle, as returned by PluginManager::registerPluginData
	 * @return Value stored, NULL if none found
	 */
	ADCHPP_DLL void* getPluginData(const PluginDataHandle& handle) const throw();

	/**
	 * Clear any data referenced by the handle, calling the registered delete function.
	 */
	ADCHPP_DLL void clearPluginData(const PluginDataHandle& handle) throw();
protected:
	virtual ~Entity();

	typedef std::map<PluginDataHandle, void*> PluginDataMap;

	uint32_t sid;

	/** SUP items */
	std::vector<uint32_t> supports;

	/** INF SU */
	std::vector<uint32_t> filters;

	/** INF fields */
	FieldMap fields;

	/** Plugin data, see PluginManager::registerPluginData */
	PluginDataMap pluginData;

	/** Latest INF cached */
	mutable BufferPtr INF;

	/** Latest SUP cached */
	mutable BufferPtr SUP;
};

}

#endif /* ADCHPP_ENTITY_H */
