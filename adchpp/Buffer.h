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

#ifndef BUFFER_H_
#define BUFFER_H_

#include "Pool.h"
#include "FastAlloc.h"

namespace adchpp {

/**
 * Reference-counted buffer
 */
class Buffer :
	public FastAlloc<Buffer>,
	private boost::noncopyable
{
public:
	Buffer(const std::string& str) : bufp(pool.get()) { append((uint8_t*)str.data(), (uint8_t*)str.data() + str.size()); }
	Buffer(const void* ptr, const size_t size) : bufp(pool.get()) { append((uint8_t*) ptr, ((uint8_t*)ptr)+size); }
	Buffer(const size_t size) : bufp(pool.get()) { resize(size); }

	operator const ByteVector&() const { return buf(); }
	operator ByteVector&() { return buf(); }

	void resize(size_t new_size) { buf().resize(new_size); }
	size_t size() const { return buf().size(); }
	const uint8_t* data() const { return &buf()[0]; }
	uint8_t* data() { return &buf()[0]; }

	/** Erase the first n bytes */
	void erase_first(size_t n) { buf().erase(buf().begin(), buf().begin() + n); }

	template<typename InputIterator>
	void append(InputIterator start, InputIterator end) { buf().insert(buf().end(), start, end); }

	static void setDefaultBufferSize(size_t newSize) { defaultBufferSize = newSize; }
	static size_t getDefaultBufferSize() { return defaultBufferSize; }

	virtual ~Buffer() { pool.put(bufp); }
private:
	static size_t defaultBufferSize;

	const ByteVector& buf() const { return *bufp; }
	ByteVector& buf() { return *bufp; }

	ByteVector* bufp;

	struct Clear {
		ADCHPP_DLL void operator()(ByteVector& x);
	};

	ADCHPP_DLL static SimplePool<ByteVector, Clear> pool;
};

typedef shared_ptr<Buffer> BufferPtr;
typedef std::vector<BufferPtr> BufferList;

}

#endif /*BUFFER_H_*/
