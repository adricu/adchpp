-- License --
See license.txt

-- Introduction --

ADCH++ is a high-performance hub for the ADC network. 

-- Requirements --

Win2k/XP/2k3 (may run on NT4 with a fresh service pack as well...don't know).
or
Linux 2.6.x

A network card with a correctly configured TCP/IP stack.
A computer that can run the above mentioned OS.
An administrator/root account (to install as service / run on port < 1024 on unix).
A brain (to read the readme and setup)
gcc 3.4+ (linux or mingw) or msvc 7.1+
stlport (on mingw, http://sf.net/projects/stlport, unzip in adchpp root)
boost (http://www.boost.org)
scons (http://www.scons.org)
swig 1.3.29+

** Important!! The hub will _NOT_ run on Win9x/ME. **

On the client side, I've only tested with DC++.

-- Building --
Install boost, swig and scons. Ensure that your compiler is available in the PATH.
To build with gcc (*nix, mingw), run "scons" in the adchpp
root folder. To build with msvc (windows), run "scons tools=default" in the adchpp 
root folder. To build build a release build, add "mode=release" to the build line.

-- Command line options --

-c <configdir>	Run with an alternate config directoy. Must be an absolute path.
-i <name> 	Install the hub service to enable running as a service. * Windows only *
-u <name>	Remove the service you created earlier. * Windows only *
-v		Print version information (make sure to include this in any bug reports)
-d		Run as a daemon. Kill with a standard sigterm. * Linux only *
-p <pid-file>	Write process pid to <pid-file> * Linux only *

-- Where to find more info --

Try http://adchpp.sf.net/ or http://dcpp.net/forum/.

-- Send in patches --
I'll gladly accept patches, but in order to avoid future licensing issues, I ask you to
give me copyright over any submitted code. Make sure that the code doesn't break support
for any of the platforms supported and that it looks more or less like the rest of the 
code (indent, names etc).
Please use patches agains latest svn trunk (i e svn diff).

-- Donate money --

If you feel like helping out but don't know how, this is obviously a good way =)...paste this link in your
browser (goes to paypal): 

https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=arnetheduck%40gmail%2ecom&item_name=DCPlusPlus&no_shipping=1&return=http%3a%2f%2fdcplusplus%2esf%2enet%2f&cancel_return=http%3a%2f%2fdcplusplus%2esf%2enet%2f&cn=Greeting&tax=0&currency_code=EUR&bn=PP%2dDonationsBF&charset=UTF%2d8
