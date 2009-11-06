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

#ifndef ADCHPP_SIMPLEXML_H
#define ADCHPP_SIMPLEXML_H

#include "Exception.h"
#include "Util.h"

namespace adchpp {

STANDARD_EXCEPTION(SimpleXMLException);

/**
 * A simple XML class that loads an XML-ish structure into an internal tree
 * and allows easy access to each element through a "current location".
 */
class SimpleXML
{
public:
	ADCHPP_DLL SimpleXML(int numAttribs = 0);
	ADCHPP_DLL ~SimpleXML();

	ADCHPP_DLL void addTag(const std::string& aName, const std::string& aData = Util::emptyString) throw(SimpleXMLException);
	void addTag(const std::string& aName, int aData) throw(SimpleXMLException) {
		addTag(aName, Util::toString(aData));
	}
	void addTag(const std::string& aName, int64_t aData) throw(SimpleXMLException) {
		addTag(aName, Util::toString(aData));
	}

	template<typename T>
	void addAttrib(const std::string& aName, const T& aData) throw(SimpleXMLException) {
		addAttrib(aName, Util::toString(aData));
	}

	ADCHPP_DLL void addAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);

	template <typename T>
    void addChildAttrib(const std::string& aName, const T& aData) throw(SimpleXMLException) {
		addChildAttrib(aName, Util::toString(aData));
	}
	ADCHPP_DLL void addChildAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);

	const std::string& getData() const {
		dcassert(current != NULL);
		return current->data;
	}

	ADCHPP_DLL void stepIn() const throw(SimpleXMLException);
	ADCHPP_DLL void stepOut() const throw(SimpleXMLException);

	void resetCurrentChild() const throw() {
		found = false;
		dcassert(current != NULL);
		currentChild = current->children.begin();
	}

	ADCHPP_DLL bool findChild(const std::string& aName) const throw();

	const std::string& getChildName() const {
		checkChildSelected();
		return (*currentChild)->name;
	}

	const std::string& getChildData() const {
		checkChildSelected();
		return (*currentChild)->data;
	}

	const std::string& getChildAttrib(const std::string& aName, const std::string& aDefault = Util::emptyString) const {
		checkChildSelected();
		return (*currentChild)->getAttrib(aName, aDefault);
	}

	int getIntChildAttrib(const std::string& aName) const {
		checkChildSelected();
		return Util::toInt(getChildAttrib(aName));
	}
	int64_t getLongLongChildAttrib(const std::string& aName) const {
		checkChildSelected();
		return Util::toInt64(getChildAttrib(aName));
	}
	bool getBoolChildAttrib(const std::string& aName) const {
		checkChildSelected();
		const std::string& tmp = getChildAttrib(aName);

		return (tmp.size() > 0) && tmp[0] == '1';
	}

	ADCHPP_DLL void fromXML(const std::string& aXML) throw(SimpleXMLException);
	std::string toXML() { return (!root->children.empty()) ? root->children[0]->toXML(0) : Util::emptyString; }

	ADCHPP_DLL static void escape(std::string& aString, bool aAttrib, bool aLoading = false);
	/**
	 * This is a heurestic for whether escape needs to be called or not. The results are
 	 * only guaranteed for false, i e sometimes true might be returned even though escape
	 * was not needed...
	 */
	static bool needsEscape(const std::string& aString, bool aAttrib, bool aLoading = false) {
		return ((aLoading) ? aString.find('&') : aString.find_first_of(aAttrib ? "<&>'\"" : "<&>")) != std::string::npos;
	}
private:
	class Tag {
	public:
		typedef Tag* Ptr;
		typedef std::vector<Ptr> List;
		typedef List::iterator Iter;
		typedef std::pair<std::string, std::string> StringPair;
		typedef std::vector<StringPair> AttribMap;
		typedef AttribMap::iterator AttribIter;

		/**
		 * A simple list of children. To find a tag, one must search the entire list.
		 */
		List children;
		/**
		 * Attributes of this tag. According to the XML standard the names
		 * must be unique (case-sensitive). (Assuming that we have few attributes here,
		 * we use a vector instead of a (hash)map to save a few bytes of memory and unnecessary
		 * calls to the memory allocator...)
		 */
		AttribMap attribs;

		/** Tag name */
		std::string name;

		/** Tag data, may be empty. */
		std::string data;

		/** Parent tag, for easy traversal */
		Ptr parent;

		Tag(const std::string& aName, const std::string& aData, Ptr aParent, int numAttribs = 0) : name(aName), data(aData), parent(aParent) {
			if(numAttribs > 0)
				attribs.reserve(numAttribs);
		}

		const std::string& getAttrib(const std::string& aName, const std::string& aDefault = Util::emptyString) {
			AttribIter i = find_if(attribs.begin(), attribs.end(), CompareFirst<std::string, std::string>(aName));
			return (i == attribs.end()) ? aDefault : i->second;
		}
		ADCHPP_DLL std::string toXML(int indent);

		std::string::size_type fromXML(const std::string& tmp, std::string::size_type start, int aa, bool isRoot = false) throw(SimpleXMLException);
		std::string::size_type loadAttribs(const std::string& tmp, std::string::size_type start) throw(SimpleXMLException);

		void appendAttribString(std::string& tmp);
		/** Delete all children! */
		~Tag() {
			for(Iter i = children.begin(); i != children.end(); ++i) {
				delete *i;
			}
		}
	};

	/** Bogus root tag, should be only one child! */
	Tag::Ptr root;

	/** Current position */
	mutable Tag::Ptr current;

	mutable Tag::Iter currentChild;

	void checkChildSelected() const throw() {
		dcassert(current != NULL);
		dcassert(currentChild != current->children.end());
	}

	int attribs;
	mutable bool found;
};

}

#endif // SIMPLEXML_H
