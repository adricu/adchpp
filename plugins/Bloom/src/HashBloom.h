#ifndef HASHBLOOM_H_
#define HASHBLOOM_H_

#include "HashValue.h"

class HashBloom {
public:
	void add(const TTHValue& tth) { bloom[pos(tth)] = true; }
	bool match(const TTHValue& tth) const { return bloom[pos(tth)]; }
	void resize(size_t hashes) { bloom.resize(hashes); std::fill(bloom.begin(), bloom.end(), false); }
	void push_back(bool v) { bloom.push_back(v); }
private:	
	
	size_t pos(const TTHValue& tth) const {
		return (*(size_t*)tth.data) % bloom.size();
	}
	
	std::vector<bool> bloom;
};

#endif /*HASHBLOOM_H_*/
