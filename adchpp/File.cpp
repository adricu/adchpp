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

#include "adchpp.h"

#include "File.h"

namespace adchpp {

using namespace std;

string File::read(uint32_t len) throw(FileException) {
	string tmp;
	tmp.resize(len);
	uint32_t x = read(&tmp[0], len);
	tmp.resize(x);
	return tmp;
}

#ifdef _WIN32

File::File(const string& aFileName, int access, int mode) throw(FileException) {
	dcassert(access == WRITE || access == READ || access == (READ | WRITE));

	int m = 0;
	if(mode & OPEN) {
		if(mode & CREATE) {
			m = (mode & TRUNCATE) ? CREATE_ALWAYS : OPEN_ALWAYS;
		} else {
			m = (mode & TRUNCATE) ? TRUNCATE_EXISTING : OPEN_EXISTING;
		}
	} else {
		if(mode & CREATE) {
			m = (mode & TRUNCATE) ? CREATE_ALWAYS : CREATE_NEW;
		} else {
			dcassert(0);
		}
	}
	int a = 0;
	if(access & READ)
		a |= GENERIC_READ;
	if(access & WRITE)
		a |= GENERIC_WRITE;

	h = ::CreateFile(aFileName.c_str(), a, FILE_SHARE_READ, NULL, m, FILE_FLAG_SEQUENTIAL_SCAN, NULL);
	
	if(h == INVALID_HANDLE_VALUE) {
		throw FileException(Util::translateError(GetLastError()));
	}

}

int64_t File::getSize() {
	DWORD x;
	DWORD l = ::GetFileSize(h, &x);
	
	if( (l == INVALID_FILE_SIZE) && (GetLastError() != NO_ERROR))
		return -1;
	
	return (int64_t)l | ((int64_t)x)<<32;
}

int64_t File::getSize(const string& aFileName) {
	WIN32_FIND_DATA fd;
	HANDLE hFind;
	
	hFind = FindFirstFile(aFileName.c_str(), &fd);
	
	if (hFind == INVALID_HANDLE_VALUE) {
		return -1;
	} else {
		FindClose(hFind);
		return ((int64_t)fd.nFileSizeHigh << 32 | (int64_t)fd.nFileSizeLow);
	}
}

string File::getFilePath(const string& path) throw() {
	string::size_type i = path.find_last_of("\\/");
	return (i != string::npos) ? path.substr(0, i) : path;
}

string File::getFileName(const string& path) throw() {
	string::size_type i = path.find_last_of("\\/");
	return (i != string::npos) ? path.substr(i + 1) : path;
}

bool File::isAbsolutePath(const string& path) throw() {
	return (path.length() >= 3 && path[1] == ':' && (path[2] == '\\' || path[2] == '/')) ||
		(path.length() >= 1 && (path[0] == '\\' || path[0] == '/'));
}

void File::ensureDirectory(const string& aFile) throw() {
	string::size_type start = 0;
	
	while( (start = aFile.find_first_of("\\/", start)) != string::npos) {
		::CreateDirectory(aFile.substr(0, start+1).c_str(), NULL);
		start++;
	}
}

#else // _WIN32

File::File(const string& aFileName, int access, int mode) throw(FileException) {
	dcassert(access == WRITE || access == READ || access == (READ | WRITE));
	
	int m = 0;
	if(access == READ)
		m |= O_RDONLY;
	else if(access == WRITE)
		m |= O_WRONLY;
	else
		m |= O_RDWR;
	
	if(mode & CREATE) {
		m |= O_CREAT;
	}
	if(mode & TRUNCATE) {
		m |= O_TRUNC;
	}
	h = open(aFileName.c_str(), m, S_IRUSR | S_IWUSR);
	if(h == -1)
		throw FileException("Could not open file");
}		

int64_t File::getSize() {
	struct stat s;
	if(fstat(h, &s) == -1)
		return -1;
	
	return (int64_t)s.st_size;
}

int64_t File::getSize(const string& aFileName) {
	struct stat s;
	if(stat(aFileName.c_str(), &s) == -1)
		return -1;
	
	return s.st_size;
}

string File::getFilePath(const string& path) throw() {
	string::size_type i = path.rfind('/');
	return (i != string::npos) ? path.substr(0, i) : path;
}

string File::getFileName(const string& path) throw() {
	string::size_type i = path.rfind('/');
	return (i != string::npos) ? path.substr(i + 1) : path;
}

bool File::isAbsolutePath(const string& path) throw() {
	return path.length() >= 1 && path[0] == '/';
}

void File::ensureDirectory(const string& aFile) throw() {
	string::size_type start = 0;
	
	while( (start = aFile.find('/', start)) != string::npos) {
		::mkdir(aFile.substr(0, start+1).c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
		start++;
	}
}
#endif

std::string File::makeAbsolutePath(const std::string& filename) {
	return makeAbsolutePath(Util::getAppPath() + PATH_SEPARATOR, filename);
}

std::string File::makeAbsolutePath(const std::string& path, const std::string& filename) {
	return isAbsolutePath(filename) ? filename : path + filename;
}

}
