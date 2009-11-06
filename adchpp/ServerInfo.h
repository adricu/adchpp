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

#ifndef ADCHPP_SERVER_INFO_H
#define ADCHPP_SERVER_INFO_H

#include "intrusive_ptr.h"

namespace adchpp {

struct ServerInfo : intrusive_ptr_base<ServerInfo> {
	std::string ip;
	unsigned short port;

	struct TLSInfo {
		std::string cert;
		std::string pkey;
		std::string trustedPath;
		std::string dh;

	private:
		friend struct ServerInfo;
		bool secure() const {
			return !cert.empty() && !pkey.empty() && !trustedPath.empty() && !dh.empty();
		}
	} TLSParams;
	bool secure() const { return TLSParams.secure(); }
};

}

#endif
