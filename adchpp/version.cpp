#include "adchpp.h"
#include "version.h"

#ifndef ADCHPP_REVISION
#define ADCHPP_REVISION 0
#endif

#define xstrver(s) strver(s)
#define strver(s) #s

#define APPNAME "ADCH++"
#define VERSIONSTRING "2.0." xstrver(ADCHPP_REVISION)
#define VERSIONFLOAT 2.0

#ifdef _DEBUG
#define BUILDSTRING "Debug"
#else
#define BUILDSTRING "Release"
#endif

#define FULLVERSIONSTRING APPNAME " v" VERSIONSTRING "-" BUILDSTRING

namespace adchpp {
	
	string appName = APPNAME;
	string versionString = FULLVERSIONSTRING;
	float versionFloat = VERSIONFLOAT;
	
}
