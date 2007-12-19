#include "stdinc.h"
#include "HashBloom.h"

size_t HashBloom::get_k(size_t n) {
	const size_t bits = TTHValue::SIZE * 8;
	for(size_t k = static_cast<size_t>(sqrt(bits)); k > 1; --k) {
		// We only want the k's where the bits will end up on a byte boundary to ease hash implementation 
		if((bits % k) == 0 && (bits / k) % 8 == 0) {
			uint64_t m = get_m(n, k);
			if(m >> (TTHValue::SIZE * 8 / k) == 0) {
				return k;
			}
		}
	}
	return 1;
}

uint64_t HashBloom::get_m(size_t n, size_t k) {
	uint64_t m = (static_cast<uint64_t>(ceil(static_cast<double>(n) * k / log(2.))));
	// 64-bit boundary allows us to use a bitset based on uint64_t's
	return ((m / 64) + 1) * 64;
}

void HashBloom::add(const TTHValue& tth) {
	for(size_t i = 0; i < k; ++i) {
		bloom[pos(tth, i)] = true;
	}
}

bool HashBloom::match(const TTHValue& tth) const {
	if(bloom.empty()) {
		return true;
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

void HashBloom::reset(size_t k_) {
	bloom.resize(0);
	k = k_;
}

size_t HashBloom::pos(const TTHValue& tth, size_t n) const {
	return (*(size_t*)(tth.data + (TTHValue::SIZE / k) * n)) % bloom.size();
}

