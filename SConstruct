# vim: set filetype: py

EnsureSConsVersion(0, 98, 5)

import os,sys
from build_util import Dev

gcc_flags = {
	'common': ['-ggdb', '-Wall', '-Wextra', '-Wno-unused-parameter', '-Wno-missing-field-initializers', '-fexceptions'],
	'debug': [], 
	'release' : ['-O3']
}

gcc_xxflags = {
	'common' : [],
	'debug' : [],
	'release' : ['-fno-enforce-eh-specs']
}

msvc_flags = {
	# 4512: assn not generated, 4100: <something annoying, forget which>, 4189: var init'd, unused, 4996: fn unsafe, use fn_s
	# 4121: alignment of member sensitive to packing
	'common' : ['/W4', '/EHsc', '/Zi', '/GR', '/wd4121', '/wd4100', '/wd4189', '/wd4996', '/wd4512'],
	'debug' : ['/MD'],
	'release' : ['/O2', '/MD']
}

msvc_xxflags = {
	'common' : [],
	'debug' : [],
	'release' : []
}

gcc_link_flags = {
	'common' : ['-ggdb', '-Wl,--no-undefined', '-time'],
	'debug' : [],
	'release' : []				
}

msvc_link_flags = {
	'common' : ['/DEBUG', '/FIXED:NO', '/INCREMENTAL:NO'],
	'debug' : [],
	'release' : []
}

msvc_defs = {
	'common' : ['_REENTRANT'],
	'debug' : ['_DEBUG'],
	'release' : ['NDEBUG']
}

gcc_defs = {
	'common' : ['_REENTRANT'],
	'debug' : ['_DEBUG'],
	'release' : ['NDEBUG']
}

# --- cut ---

import os,sys,distutils.sysconfig

plugins = filter(lambda x: os.path.isfile(os.path.join('plugins', x, 'SConscript')), os.listdir('plugins'))

defEnv = Environment(ENV = os.environ)
opts = Variables('custom.py', ARGUMENTS)

if sys.platform == 'win32':
	tooldef = 'mingw'
else:
	tooldef = 'default'

opts.AddVariables(
	EnumVariable('tools', 'Toolset to compile with, default = platform default (msvc under windows)', tooldef, ['mingw', 'default']),
	EnumVariable('mode', 'Compile mode', 'debug', ['debug', 'release']),
	ListVariable('plugins', 'The plugins to compile', 'all', plugins),
	BoolVariable('nativestl', 'Use native STL instead of STLPort', 'yes'),
	BoolVariable('gch', 'Use GCH when compiling GUI (disable if you have linking problems with mingw)', 'yes'),
	BoolVariable('verbose', 'Show verbose command lines', 'no'),
	BoolVariable('savetemps', 'Save intermediate compilation files (assembly output)', 'no'),
	BoolVariable('i18n', 'Rebuild i18n files in debug build', 'no'),
	BoolVariable('nls', 'Build with internationalization support', 'yes'),
	('prefix', 'Prefix to use when cross compiling', 'i386-mingw32-'),
	('python', 'Python path to use when compiling python extensions', distutils.sysconfig.get_config_var('prefix'))
)

opts.Update(defEnv)
Help(opts.GenerateHelpText(defEnv))

tools = ARGUMENTS.get('tools', tooldef)

toolset = [tools, 'swig']

env = Environment(ENV=os.environ, tools = toolset, options=opts)

mode = env['mode']
if mode not in gcc_flags:
	print "Unknown mode, exiting"
	Exit(1)

dev = Dev(mode, tools, env)
dev.prepare()

env.SConsignFile()

env.Append(CPPPATH = ["#/boost/boost/tr1/tr1/", "#/boost/"])
env.Append(CPPDEFINES = ['BOOST_ALL_DYN_LINK=1'])

if not dev.is_win32():
	env.Append(CPPDEFINES = ['_XOPEN_SOURCE=500'] )
	env.Append(CCFLAGS=['-fvisibility=hidden'])

if env['nativestl']:
	if 'gcc' in env['TOOLS']:
		env.Append(CPPDEFINES = ['BOOST_HAS_GCC_TR1'])
	# boost detects MSVC's tr1 automagically
else:
	env.Append(CPPPATH = ['#/stlport/stlport/'])
	env.Append(LIBPATH = ['#/stlport/lib/'])
	env.Append(CPPDEFINES = ['HAVE_STLPORT', '_STLP_USE_STATIC_LIB=1'])
	if mode == 'debug':
		env.Append(LIBS = ['stlportg.5.1'])
	else:
		env.Append(LIBS = ['stlport.5.1'])	

	# assume STLPort has tr1 containers
	env.Append(CPPDEFINES = ['BOOST_HAS_TR1'])

if 'gcc' in env['TOOLS']:
	if env['savetemps']:
		env.Append(CCFLAGS = ['-save-temps', '-fverbose-asm'])
	else:
		env.Append(CCFLAGS = ['-pipe'])

if env['CC'] == 'cl': # MSVC
	flags = msvc_flags
	xxflags = msvc_xxflags
	link_flags = msvc_link_flags
	defs = msvc_defs
	
	# This is for msvc8
	# Embed generated manifest in file
	env['SHLINKCOM'] = [env['SHLINKCOM'], 'mt.exe -manifest ${TARGET}.manifest -outputresource:$TARGET;2']
	env['LINKCOM'] = [env['LINKCOM'], 'mt.exe -manifest ${TARGET}.manifest -outputresource:$TARGET;1']
else:
	flags = gcc_flags
	xxflags = gcc_xxflags
	link_flags = gcc_link_flags
	defs = gcc_defs

	env.Tool("gch", toolpath=".")

env.Append(CPPDEFINES = defs[mode])
env.Append(CPPDEFINES = defs['common'])

env.Append(CCFLAGS = flags[mode])
env.Append(CCFLAGS = flags['common'])

env.Append(LINKFLAGS = link_flags[mode])
env.Append(LINKFLAGS = link_flags['common'])

if dev.is_win32():
	env.Append(LIBS = ['ws2_32', 'mswsock'])

env.SourceCode('.', None)

import SCons.Scanner
SWIGScanner = SCons.Scanner.ClassicCPP(
	"SWIGScan",
	".i",
	"CPPPATH",
	'^[ \t]*[%,#][ \t]*(?:include|import)[ \t]*(<|")([^>"]+)(>|")'
)
env.Append(SCANNERS=[SWIGScanner])

#
# internationalization (ardour.org provided the initial idea)
#

po_args = ['msgmerge', '-q', '--update', '--backup=none', '--no-location', '$TARGET', '$SOURCE']
po_bld = Builder (action = Action([po_args], 'Updating translation $TARGET from $SOURCES'))
env.Append(BUILDERS = {'PoBuild' : po_bld})

mo_args = ['msgfmt', '-c', '-o', '$TARGET', '$SOURCE']
mo_bld = Builder (action = Action([mo_args], 'Compiling message catalog $TARGET from $SOURCES'))
env.Append(BUILDERS = {'MoBuild' : mo_bld})

pot_args = ['xgettext', '--from-code=UTF-8', '--foreign-user', '--package-name=$PACKAGE',
		'--copyright-holder=Jacek Sieka', '--msgid-bugs-address=dcplusplus-devel@lists.sourceforge.net',
		'--no-wrap', '--keyword=_', '--keyword=T_', '--keyword=TF_', '--keyword=TFN_:1,2',
		'--keyword=F_', '--keyword=gettext_noop', '--keyword=N_', '--keyword=CT_', '--boost', '-s',
		'--output=$TARGET', '$SOURCES']

pot_bld = Builder (action = Action([pot_args], 'Extracting messages to $TARGET from $SOURCES'))
env.Append(BUILDERS = {'PotBuild' : pot_bld})

conf = Configure(env)

if conf.CheckCHeader('poll.h'):
	conf.env.Append(CPPDEFINES='HAVE_POLL_H')
if conf.CheckCHeader('sys/epoll.h'):
	conf.env.Append(CPPDEFINES=['HAVE_SYS_EPOLL_H'])
if conf.CheckLib('dl', 'dlopen'):
	conf.env.Append(CPPDEFINES=['HAVE_DL'])
if conf.CheckLib('pthread', 'pthread_create'):
	conf.env.Append(CPPDEFINES=['HAVE_PTHREAD'])
if conf.CheckLib('ssl', 'SSL_connect') or os.path.exists(Dir('#/openssl/include').abspath):
	conf.env.Append(CPPDEFINES=['HAVE_OPENSSL'])
	
env = conf.Finish()

#dev.intl = dev.build('intl/')

env.Append(LIBPATH = env.Dir(dev.get_build_root() + 'bin/').abspath)
if not dev.is_win32():
	dev.env.Append(RPATH = env.Literal('\\$$ORIGIN'))

dev.boost_system = dev.build('boost/libs/system/src/')

env.Append(LIBS = ['aboost_system'])

dev.adchpp = dev.build('adchpp/')

dev.build('adchppd/')

# Lua for plugins & swig
dev.build('lua/')

# Library wrappers
dev.build('swig/')

# Plugins
for plugin in env['plugins']:
	dev.build('plugins/' + plugin + '/')

