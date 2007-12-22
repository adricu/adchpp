= ADCH++ - A hub software for ADC

== Introduction

ADCH++ is a hub for the ADC network. It implements the
http://dcplusplus.sf.net/ADC.html[ADC protocol]. The core application is very
simple, but extensible using plugins. Among the standard plugins there is a
scripting plugin that allows hub owners to further customize the hub using the
http://www.lua.org[Lua] scripting language. The core is also exposed as a
Python module, thus it is possible to use it within a Python application.

== License
ADCH++ is licensed under the GPL. For details, see license.txt supplied with
the application. A side effect of the license is that any plugins you write
must be released under a license compatible with the GPL.

== Download
The latest version of ADCH++ can be downloaded from
http://sourceforge.net/projects/adchpp/[SourceForge]. The source code resides
in http://sourceforge.net/svn/?group_id=172105[SVN].

== Requirements
To run ADCH++ you will need the following:

* A computer with a network card
* Linux with a 2.6-based kernel or Windows 2000/XP
* A brain (to understand the readme and do the setup)
* Optional: An administrator account (to install as service / run on port < 1024 on
  unix)

NOTE: The hub will not run on Windows 9x/ME

To compile the sources you will also need:

* GCC 4.2+ (Linux or http://www.mingw.org[MinGW])
* http://www.scons.org[SCons 0.97]
* http://www.swig.org[SWIG 1.3.33]
* http://www.python.org[Python] 2.5 (Windows) or 2.4+ (Linux)

== Building
To build ADCH++ from source you have to:

* Install SWIG and ensure it's in your PATH
* Install Python and ensure it's in your PATH
* Install SCons and ensure it's in your PATH
* Windows: Install MinGW and ensure it's in your PATH
* Linux: Install GCC 4.2+ and appropriate header files
* In the source folder, type "scons -h" to see additional compile options
* Type "scons" to create a debug build. "scons mode=release" will create a
  release build.

== Configuration
ADCH++ is configured using an XML file, as are the standard plugins. The
example configuration contains enough comments to get you started. In Linux,
the default location for configuration files is "/etc/adchpp/". In Windows, it's
a directory named "config" under the installation directory.

== Running
ADCH++ will normally run as a console / terminal application but can also be
convinced to run in the background (daemon/service). It accepts various
command line options such as:

[separator="|"]
``_
-c <configdir> | Run with an alternate config directoy. Must be an absolute path.
-i <name>      | Install the hub service to enable running as a service. * Windows only *
-u <name>      | Remove the service you created earlier. * Windows only *
-v             | Print version information (make sure to include this in any bug reports)
-d             | Run as a daemon. Kill with a standard sigterm. * Linux only *
-p <pid-file>  | Write process pid to <pid-file> * Linux only *
___

== Where to find more info
Try its http://adchpp.sf.net/[home page] or the
http://dcplusplus.sf.net/[DC++ home page].

== Patches and contributions
I'll gladly accept patches, but in order to avoid future licensing issues, I ask you to
give me copyright over any submitted code. Make sure that the code doesn't break support
for any of the platforms supported and that it looks more or less like the
rest of the code (indent, names etc).

Patches should be sent to the dcplusplus-devel mailing list. Subscription
information can be found 
https://lists.sourceforge.net/lists/listinfo/dcplusplus-devel[here].

Please use unified patches agains latest svn trunk (i e svn diff) and supply a
description of what the patch does.

== Donations

If you feel like helping out but don't know how, this is obviously a good way
=)

https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=arnetheduck%40gmail%2ecom&item_name=DCPlusPlus&no_shipping=1&return=http%3a%2f%2fdcplusplus%2esf%2enet%2f&cancel_return=http%3a%2f%2fdcplusplus%2esf%2enet%2f&cn=Greeting&tax=0&currency_code=EUR&bn=PP%2dDonationsBF&charset=UTF%2d8[Donate!]

// vim: set syntax=asciidoc:

