# vim: set filetype: py

from build_util import Dev

gcc_flags = {
	'common': ['-ggdb3', '-Wall', '-Wextra', '-pipe'],
	'debug': [], 
	'release' : ['-O3']
}

msvc_flags = {
	'common' : ['/W4', '/EHsc', '/Zi', '/GR'],
	'debug' : ['/MD'],
	'release' : ['/O2', '/MD']
}

gcc_link_flags = {
	'common' : ['-ggdb3', '-Wl,--no-undefined'],
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

import SCons
if SCons.__version__ != "0.96.1":
	import sys
	print "Only builds with SCons 0.96.1, you have", SCons.__version__
	sys.exit()

import os,sys

if sys.platform == 'win32':
	tooldef = 'mingw'
else:
	tooldef = 'default'

mode = ARGUMENTS.get('mode', 'debug')
tools = ARGUMENTS.get('tools', tooldef)

if mode not in gcc_flags:
	print "Unknown mode, exiting"
	Exit(1)

toolset = [tools, 'swig']

env = Environment(tools = toolset, ENV=os.environ)

env.SConsignFile()
env.Tool("gch", toolpath=".")

if env['PLATFORM'] == 'win32':
	env.Append(CPPPATH = [r'c:\Boost\include\boost-1_33_1'])
else:
	env.Append(CPPDEFINES = ['_XOPEN_SOURCE=500'] )
	env.Append(CCFLAGS=['-fvisibility=hidden'])
	
if 'mingw' in env['TOOLS']:
	env.Append(CPPPATH = ['#/STLport/stlport/'])
	env.Append(LIBPATH = ['#/STLport/lib/'])
	env.Append(CPPDEFINES = ['HAVE_STLPORT'])
	
	gcc_link_flags['common'].append("-Wl,--enable-runtime-pseudo-reloc")
	if mode == 'debug':
		env.Append(LIBS = ['stlportg.5.0'])
	else:
		env.Append(LIBS = ['stlport.5.0'])	

if env['CC'] == 'cl':
	flags = msvc_flags
	link_flags = msvc_link_flags
	defs = msvc_defs
	
	# This is for msvc8
	# Embed generated manifest in file
	env['SHLINKCOM'] = [env['SHLINKCOM'], 'mt.exe -manifest ${TARGET}.manifest -outputresource:$TARGET;2']
	env['LINKCOM'] = [env['LINKCOM'], 'mt.exe -manifest ${TARGET}.manifest -outputresource:$TARGET;1']
else:
	flags = gcc_flags
	link_flags = gcc_link_flags
	defs = gcc_defs

env.Append(CPPDEFINES = defs[mode])
env.Append(CPPDEFINES = defs['common'])

env.Append(CCFLAGS = flags[mode])
env.Append(CCFLAGS = flags['common'])

env.Append(LINKFLAGS = link_flags[mode])
env.Append(LINKFLAGS = link_flags['common'])

env.SourceCode('.', None)
env.SetOption('implicit_cache', '1')
env.SetOption('max_drift', 60*10)

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

dev = Dev(mode, tools, env)

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
