/* 
 * Copyright (C) 2006-2007 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_FILE_H
#define ADCHPP_FILE_H

#include "Exception.h"
#include "Util.h"
#include "ResourceManager.h"

#ifndef _WIN32
#include <sys/stat.h>
#include <fcntl.h>
#endif

namespace adchpp {

STANDARD_EXCEPTION(FileException);

class File
{
public:
	enum {
		READ = 0x01,
		WRITE = 0x02
	};
	
	enum {
		OPEN = 0x01,
		CREATE = 0x02,
		TRUNCATE = 0x04
	};

	ADCHPP_DLL File(const string& aFileName, int access, int mode = OPEN) throw(FileException);

	ADCHPP_DLL int64_t getSize();
	ADCHPP_DLL static int64_t getSize(const string& aFileName);

	ADCHPP_DLL string read(uint32_t len) throw(FileException);
	
	/** Returns the directory part of the full path */
	ADCHPP_DLL static string getFilePath(const string& name) throw();
	/** Returns the filename part of the full path */
	ADCHPP_DLL static string getFileName(const string& name) throw();
	ADCHPP_DLL static bool isAbsolutePath(const string& name) throw();
	
	static string makeAbsolutePath(string const& path, string const& filename) {
		return isAbsolutePath(filename) ? filename : path + filename;
	}

	ADCHPP_DLL static void ensureDirectory(const string& aFile) throw();
	
#ifdef _WIN32
	void close() {
		if(h != INVALID_HANDLE_VALUE) {
			CloseHandle(h);
			h = INVALID_HANDLE_VALUE;
		}
	}
	
	int64_t getPos() {
		LONG x = 0;
		DWORD l = ::SetFilePointer(h, 0, &x, FILE_CURRENT);
		
		return (int64_t)l | ((int64_t)x)<<32;
	}		

	void setPos(int64_t pos) {
		LONG x = (LONG) (pos>>32);
		::SetFilePointer(h, (DWORD)(pos & 0xffffffff), &x, FILE_BEGIN);
	}		
	void setEndPos(int64_t pos) {
		LONG x = (LONG) (pos>>32);
		::SetFilePointer(h, (DWORD)(pos & 0xffffffff), &x, FILE_END);
	}		

	void movePos(int64_t pos) {
		LONG x = (LONG) (pos>>32);
		::SetFilePointer(h, (DWORD)(pos & 0xffffffff), &x, FILE_CURRENT);
	}
	
	uint32_t read(void* buf, uint32_t len) throw(FileException) {
		DWORD x;
		if(!::ReadFile(h, buf, len, &x, NULL)) {
			throw(FileException(Util::translateError(GetLastError())));
		}
		return x;
	}

	void write(const void* buf, size_t len) throw(FileException) {
		DWORD x;
		if(!::WriteFile(h, buf, (DWORD)len, &x, NULL)) {
			throw FileException(Util::translateError(GetLastError()));
		}
		if(x < len) {
			throw FileException(STRING(DISK_FULL));
		}
	}
	
	void setEOF() throw(FileException) {
		dcassert(h != NULL);
		if(!SetEndOfFile(h)) {
			throw FileException(Util::translateError(GetLastError()));
		}
	}

	static void deleteFile(const string& aFileName) { ::DeleteFile(aFileName.c_str()); };
	static void renameFile(const string& source, const string& target) { ::MoveFile(source.c_str(), target.c_str()); };

#else // WIN32
	
	void close() {
		if(h != -1) {
			::close(h);
			h = -1;
		}
	}

	int64_t getPos() { return (int64_t) lseek(h, 0, SEEK_CUR); }

	void setPos(int64_t pos) { lseek(h, (off_t)pos, SEEK_SET); };
	void setEndPos(int64_t pos) { lseek(h, (off_t)pos, SEEK_END); };
	void movePos(int64_t pos) { lseek(h, (off_t)pos, SEEK_CUR); };

	uint32_t read(void* buf, uint32_t len) throw(FileException) {
		ssize_t x = ::read(h, buf, (size_t)len);
		if(x == -1)
			throw FileException(Util::translateError(errno));
		return (uint32_t)x;
	}
	
	void write(const void* buf, uint32_t len) throw(FileException) {
		ssize_t x;
		x = ::write(h, buf, len);
		if(x == -1)
			throw FileException(Util::translateError(errno));
		if(x < (ssize_t)len)
			throw FileException(STRING(DISK_FULL));
	}

	/**
	 * @todo fix for unix...
	 */
	void setEOF() throw(FileException) {
	}

	static void deleteFile(const string& aFileName) { ::unlink(aFileName.c_str()); };
	static void renameFile(const string& source, const string& target) { ::rename(source.c_str(), target.c_str()); };
	
#endif // WIN32

	~File() {
		close();
	}

	string read() throw(FileException) {
		setPos(0);
		return read((uint32_t)getSize());
	}

	void write(const string& aString) throw(FileException) {
		write((void*)aString.data(), aString.size());
	}
		
private:
	File(const File&);
	File& operator=(const File&);
	
#ifdef _WIN32
	HANDLE h;
#else
	int h;
#endif

};

}

#endif // FILE_H
