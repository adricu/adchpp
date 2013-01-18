/*
 * Copyright (C) 2006-2013 Jacek Sieka, arnetheduck on gmail point com
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

#include <boost/system/error_code.hpp>
#include "Buffer.h"

namespace adchpp {

class AsyncStream : private boost::noncopyable {
public:
	typedef std::function<void (const boost::system::error_code& ec, size_t)> Handler;

	virtual size_t available() = 0;
	virtual void init(const std::function<void ()>& postInit) = 0;
	virtual void setOptions(size_t bufferSize) = 0;
	virtual std::string getIp() = 0;
	virtual void prepareRead(const BufferPtr& buf, const Handler& handler) = 0;
	virtual size_t read(const BufferPtr& buf) = 0;
	virtual void write(const BufferList& bufs, const Handler& handler) = 0;
	virtual void shutdown(const Handler& handler) = 0;
	virtual void close() = 0;

	virtual ~AsyncStream() { }
};

typedef shared_ptr<AsyncStream> AsyncStreamPtr;

}
