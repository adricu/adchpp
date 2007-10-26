# vim: set filetype: py

from build_util import Dev

opts = Options('custom.py', ARGUMENTS)

opts.AddOptions(
	EnumOption('tools', 'Toolset to compile with, default = platform default (msvc under windows)', 'mingw', ['mingw', 'default']),
	EnumOption('mode', 'Compile mode', 'debug', ['debug', 'release']),
	BoolOption('nativestl', 'Use native STL instead of STLPort', 'yes'),
	BoolOption('verbose', 'Show verbose command lines', 'no'),
	BoolOption('savetemps', 'Save intermediate compilation files (assembly output)', 'no'),
	('prefix', 'Prefix to use when cross compiling', 'i386-mingw32-')
)

gcc_flags = {
	'common': ['-ggdb', '-Wall', '-Wextra', '-pipe', '-Wno-unused-parameter', '-Wno-missing-field-initializers', '-fexceptions'],
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
	'debug' : [''],
	'release' : ['NDEBUG']
}

gcc_defs = {
	'common' : ['_REENTRANT'],
	'debug' : ['_DEBUG'],
	'release' : ['NDEBUG']
}

# --- cut ---

import os,sys

if sys.platform == 'win32':
	tooldef = 'mingw'
else:
	tooldef = 'default'

tools = ARGUMENTS.get('tools', tooldef)

toolset = [tools, 'swig']

env = Environment(tools = toolset, options=opts, ENV=os.environ)
Help(opts.GenerateHelpText(env))


mode = env['mode']
if mode not in gcc_flags:
	print "Unknown mode, exiting"
	Exit(1)

dev = Dev(mode, tools, env)
dev.prepare()

env.SConsignFile()
if('gcc' in env['TOOLS']):
	env.Tool("gch", toolpath=".")

env.Append(CPPPATH = ["#/boost/boost/tr1/tr1/", "#/boost/"])

if env['PLATFORM'] != 'win32':
	env.Append(CPPDEFINES = ['_XOPEN_SOURCE=500'] )
	env.Append(CCFLAGS=['-fvisibility=hidden'])

if not env['nativestl']:
	env.Append(CPPPATH = ['#/stlport/stlport/'])
	env.Append(LIBPATH = ['#/stlport/lib/'])
	env.Append(CPPDEFINES = ['HAVE_STLPORT', '_STLP_USE_STATIC_LIB=1'])
	if mode == 'debug':
		env.Append(LIBS = ['stlportg.5.1'])
	else:
		env.Append(LIBS = ['stlport.5.1'])	
elif 'gcc' in env['TOOLS']:
	env.Append(CPPDEFINES = ['BOOST_HAS_GCC_TR1'])

if env['savetemps'] and 'gcc' in env['TOOLS']:
	env.Append(CCFLAGS = ['-save-temps', '-fverbose-asm'])


if env['CC'] == 'cl':
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

env.Append(CPPDEFINES = defs[mode])
env.Append(CPPDEFINES = defs['common'])

env.Append(CCFLAGS = flags[mode])
env.Append(CCFLAGS = flags['common'])

env.Append(LINKFLAGS = link_flags[mode])
env.Append(LINKFLAGS = link_flags['common'])

env.SourceCode('.', None)

import SCons.Scanner
SWIGScanner = SCons.Scanner.ClassicCPP(
	"SWIGScan",
	".i",
	"CPPPATH",
	'^[ \t]*[%,#][ \t]*(?:include|import)[ \t]*(<|")([^>"]+)(>|")'
)
env.Append(SCANNERS=[SWIGScanner])

conf = Configure(env)

if conf.CheckCHeader('sys/epoll.h'):
	conf.env.Append(CPPDEFINES='HAVE_SYS_EPOLL_H')
if conf.CheckCHeader('sys/poll.h'):
	conf.env.Append(CPPDEFINES='HAVE_SYS_POLL_H')
if conf.CheckLib('dl', 'dlopen'):
	conf.env.Append(CPPDEFINES='HAVE_DL')
if conf.CheckLib('pthread', 'pthread_create'):
	conf.env.Append(CPPDEFINES='HAVE_PTHREAD')

env = conf.Finish()

dev.adchpp = dev.build('adchpp/')

if env['PLATFORM'] == 'win32' or env['PLATFORM'] == 'cygwin':
	dev.build('windows/')
else:
	dev.build('unix/')

# Lua for plugins & swig
dev.build('lua/')

# Library wrappers
dev.build('swig/')

# Plugins
dev.build('plugins/Script/')
dev.build('plugins/Bloom/')

