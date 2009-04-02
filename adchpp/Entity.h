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

#ifndef ADCHPP_ENTITY_H
#define ADCHPP_ENTITY_H

#include "forward.h"
#include "Buffer.h"
#include "AdcCommand.h"

namespace adchpp {

class Entity {
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

protected:
	uint32_t sid;

	/** SUP items */
	std::vector<uint32_t> supports;

	/** INF SU */
	std::vector<uint32_t> filters;

	/** INF fields */
	FieldMap fields;

	/** Latest INF cached */
	mutable BufferPtr INF;

	/** Latest SUP cached */
	mutable BufferPtr SUP;
};

}

#endif /* ADCHPP_ENTITY_H */
