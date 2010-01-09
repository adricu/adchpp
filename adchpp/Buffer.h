#ifndef BUFFER_H_
#define BUFFER_H_

#include "intrusive_ptr.h"
#include "Pool.h"
#include "FastAlloc.h"

namespace adchpp {

/**
 * Reference-counted buffer
 */
class Buffer : public intrusive_ptr_base<Buffer>, public FastAlloc<Buffer> {
public:
	Buffer(const std::string& str) : bufp(pool.get()) { append((uint8_t*)str.data(), (uint8_t*)str.data() + str.size()); }
	Buffer(const void* ptr, const size_t size) : bufp(pool.get()) { append((uint8_t*) ptr, ((uint8_t*)ptr)+size); }
	Buffer(const size_t size) : bufp(pool.get()) { resize(size); }
	~Buffer() { pool.put(bufp); }

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

typedef boost::intrusive_ptr<Buffer> BufferPtr;
typedef std::vector<BufferPtr> BufferList;

}

#endif /*BUFFER_H_*/
