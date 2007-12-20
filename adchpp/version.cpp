#include "adchpp.h"
#include "version.h"

#ifndef ADCHPP_REVISION
#define ADCHPP_REVISION 0
#endif

#define xstrver(s) strver(s)
#define strver(s) #s

#define APPNAME "ADCH++"
#define VERSIONSTRING "2.1.0 (r" xstrver(ADCHPP_REVISION) ")"
#define VERSIONFLOAT 2.1

#ifndef NDEBUG
#define BUILDSTRING "Debug"
#else
#define BUILDSTRING "Release"
#endif

#define FULLVERSIONSTRING APPNAME " v" VERSIONSTRING "-" BUILDSTRING

namespace adchpp {

using namespace std;

string appName = APPNAME;
string versionString = FULLVERSIONSTRING;
float versionFloat = VERSIONFLOAT;

}
