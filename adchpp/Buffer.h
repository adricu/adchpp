#ifndef BUFFER_H_
#define BUFFER_H_

#include "FastAlloc.h"

namespace adchpp {

/**
 * Reference-counted buffer
 */
class Buffer : public intrusive_ptr_base, public FastAlloc<Buffer> {
public:
	Buffer(const std::string& str) : buf((uint8_t*)str.data(), (uint8_t*)str.data() + str.size()) { }
	Buffer(const void* ptr, const size_t size) : buf((uint8_t*) ptr, ((uint8_t*)ptr)+size) { }
	Buffer(const size_t size) : buf(size) { }
	
	operator const ByteVector&() const { return buf; }
	operator ByteVector&() { return buf; }
	
	void resize(size_t new_size) { buf.resize(new_size); } 
	size_t size() const { return buf.size(); }
	const uint8_t* data() const { return &buf[0]; }
	uint8_t* data() { return &buf[0]; }
	
	/** Erase the first n bytes */
	void erase_first(size_t n) {
		buf.erase(buf.begin(), buf.begin() + n);
	}
	
	template<typename InputIterator>
	void append(InputIterator start, InputIterator end) {
		buf.insert(buf.end(), start, end);
	}
private:
	ByteVector buf;
};

typedef boost::intrusive_ptr<Buffer> BufferPtr;
typedef std::vector<BufferPtr> BufferList;

}

#endif /*BUFFER_H_*/
