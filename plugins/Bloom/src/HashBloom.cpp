#include "stdinc.h"

#include "HashBloom.h"

#include <math.h>

size_t HashBloom::get_k(size_t n, size_t h) {
	for(size_t k = TTHValue::BITS/h; k > 1; --k) {
		uint64_t m = get_m(n, k);
		if(m >> 24 == 0) {
			return k;
		}
	}
	return 1;
}

uint64_t HashBloom::get_m(size_t n, size_t k) {
	uint64_t m = (static_cast<uint64_t>(ceil(static_cast<double>(n) * k / log(2.))));
	// 64-bit boundary as per spec
	return ((m + 63 )/ 64) * 64;
}

void HashBloom::add(const TTHValue& tth) {
	for(size_t i = 0; i < k; ++i) {
		bloom[pos(tth, i)] = true;
	}
}

bool HashBloom::match(const TTHValue& tth) const {
	if(bloom.empty()) {
		return false;
	}
	for(size_t i = 0; i < k; ++i) {
		if(!bloom[pos(tth, i)]) {
			return false;
		}
	}
	return true;
}

void HashBloom::push_back(bool v) {
	bloom.push_back(v);
}

void HashBloom::reset(ByteVector& v, size_t k_, size_t h_) {
	k = k_;
	h = h_;
	
	bloom.resize(v.size() * 8);
	for(size_t i = 0; i < v.size(); ++i) {
		for(size_t j = 0; j < 8; ++j) {
			bloom[i*8 + j] = (((v[i] >> j) & 1) != 0);
		}
	}
}

size_t HashBloom::pos(const TTHValue& tth, size_t n) const {
	if((n+1)*h > TTHValue::BITS) {
		return 0;
	}

	uint64_t x = 0;
	
	size_t start = n * h;
	
	for(size_t i = 0; i < h; ++i) {
		size_t bit = start + i;
		size_t byte = bit / 8;
		size_t pos = bit % 8;
		
		if(tth.data[byte] & (1 << pos)) {
			x |= (1 << i);
		}
	}
	return x % bloom.size();
}

