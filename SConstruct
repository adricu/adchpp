# vim: set filetype: py

EnsureSConsVersion(1, 2)

import os,sys
from build_util import Dev

gcc_flags = {
	'common': ['-g', '-Wall', '-Wextra', '-Wno-unused-parameter', '-Wno-missing-field-initializers', '-fexceptions'],
	'debug': [], 
	'release' : ['-O3']
}

gcc_xxflags = {
	'common' : ['-std=gnu++0x'],
	'debug' : [],
	'release' : []
}

msvc_flags = {
	# 4100: unreferenced formal parameter
	# 4121: alignment of member sensitive to packing
	# 4127: conditional expression is constant
	# 4189: var init'd, unused
	# 4290: exception spec ignored
	# 4510: no default constructor
	# 4512: assn not generated
	# 4610: no default constructor
	# 4800: converting from BOOL to bool
	# 4996: fn unsafe, use fn_s
	'common' : ['/W4', '/EHsc', '/Zi', '/GR', '/wd4100', '/wd4121', '/wd4127', '/wd4189', '/wd4290', '/wd4510', '/wd4512', '/wd4610', '/wd4800', '/wd4996'],
	'debug' : ['/MDd', '/LDd'],
	'release' : ['/O2', '/MD', '/LD']
}
# we set /LD(d) by default for all sub-projects, since most of them are DLLs. don't forget to
# remove it when building executables!

msvc_xxflags = {
	'common' : [],
	'debug' : [],
	'release' : []
}

gcc_link_flags = {
	'common' : ['-g', '-Wl,--no-undefined', '-time'],
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
	'debug' : ['_DEBUG', '_HAS_ITERATOR_DEBUGGING=0', '_SECURE_SCL=0'],
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
	EnumVariable('tools', 'Toolset to compile with, default = platform default (msvc under windows)', tooldef, ['mingw', 'default', 'clang']),
	EnumVariable('mode', 'Compile mode', 'debug', ['debug', 'release']),
	ListVariable('plugins', 'The plugins to compile', 'all', plugins),
	BoolVariable('gch', 'Use GCH when compiling GUI (disable if you have linking problems with mingw)', 'yes'),
	BoolVariable('verbose', 'Show verbose command lines', 'no'),
	BoolVariable('savetemps', 'Save intermediate compilation files (assembly output)', 'no'),
	('prefix', 'Prefix to use when cross compiling', ''),
	EnumVariable('arch', 'Target architecture', 'x86', ['x86', 'x64', 'ia64']),
	('python', 'Python path to use when compiling python extensions', distutils.sysconfig.get_config_var('prefix')),
	BoolVariable('docs', 'Build docs (requires asciidoc)', 'no')
)

opts.Update(defEnv)
Help(opts.GenerateHelpText(defEnv))

# workaround for SCons 1.2 which hard-codes possible archs (only allows 'x86' and 'amd64'...)
# TODO remove when SCons knows about all available archs
TARGET_ARCH = defEnv['arch']
if TARGET_ARCH == 'x64':
	TARGET_ARCH = 'amd64'

env = Environment(ENV = os.environ, tools = [defEnv['tools'], 'swig'], toolpath = ['tools'], options = opts, TARGET_ARCH = TARGET_ARCH, MSVS_ARCH = TARGET_ARCH)

# filter out boost from dependencies to get a speedier rebuild scan
# this means that if boost changes, scons -c needs to be run
# delete .sconsign.dblite to see the effects of this if you're upgrading
def filterBoost(x):
	return [y for y in x if str(y).find('boost') == -1]

SourceFileScanner.function['.c'].recurse_nodes = filterBoost
SourceFileScanner.function['.cpp'].recurse_nodes = filterBoost
SourceFileScanner.function['.h'].recurse_nodes = filterBoost
SourceFileScanner.function['.hpp'].recurse_nodes = filterBoost

dev = Dev(env)
dev.prepare()

env.SConsignFile()

env.Append(CPPPATH = ['#/boost/'])
env.Append(CPPDEFINES = ['BOOST_ALL_DYN_LINK=1'])
if env['CC'] == 'cl': # MSVC
	env.Append(CPPDEFINES = ['BOOST_ALL_NO_LIB=1'])

if not dev.is_win32():
	env.Append(CPPDEFINES = ['_XOPEN_SOURCE=500'] )
	env.Append(CCFLAGS=['-fvisibility=hidden'])
	env.Append(LIBS = ['stdc++', 'm'])

if 'gcc' in env['TOOLS']:
	if dev.is_win32():
		env.Append(LINKFLAGS = ['-Wl,--enable-auto-import'])

	if env['savetemps']:
		env.Append(CCFLAGS = ['-save-temps', '-fverbose-asm'])
	else:
		env.Append(CCFLAGS = ['-pipe'])

if env['CC'] == 'cl': # MSVC
	flags = msvc_flags
	xxflags = msvc_xxflags
	link_flags = msvc_link_flags
	defs = msvc_defs

	if env['arch'] == 'x86':
		env.Append(CPPDEFINES = ['_USE_32BIT_TIME_T=1']) # for compatibility with PHP

else:
	flags = gcc_flags
	xxflags = gcc_xxflags
	link_flags = gcc_link_flags
	defs = gcc_defs

	env.Tool("gch", toolpath=".")

env.Append(CPPDEFINES = defs[env['mode']])
env.Append(CPPDEFINES = defs['common'])

env.Append(CCFLAGS = flags[env['mode']])
env.Append(CCFLAGS = flags['common'])

env.Append(CXXFLAGS = xxflags[env['mode']])
env.Append(CXXFLAGS = xxflags['common'])

env.Append(LINKFLAGS = link_flags[env['mode']])
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

if not env.GetOption('clean') and not env.GetOption("help"):
	conf = Configure(env, conf_dir = dev.get_build_path('.sconf_temp'), log_file = dev.get_build_path('config.log'), clean = False, help = False)

	if conf.CheckCHeader('ruby.h'):
		conf.env['HAVE_RUBY_H'] = True
	if not dev.is_win32():
		if conf.CheckCHeader('poll.h'):
			conf.env.Append(CPPDEFINES='HAVE_POLL_H')
		if conf.CheckCHeader('sys/epoll.h'):
			conf.env.Append(CPPDEFINES=['HAVE_SYS_EPOLL_H'])
		if conf.CheckLib('pthread', 'pthread_create'):
			conf.env.Append(CPPDEFINES=['HAVE_PTHREAD'])
		if conf.CheckLib('ssl', 'SSL_connect'):
			conf.env.Append(CPPDEFINES=['HAVE_OPENSSL'])
		if conf.CheckLib('dl', 'dlopen'):
			conf.env.Append(CPPDEFINES=['HAVE_DL'])
	else:
		if os.path.exists(Dir('#/openssl/include').abspath):
			conf.env.Append(CPPDEFINES=['HAVE_OPENSSL'])

	env = conf.Finish()

env.Append(LIBPATH = env.Dir(dev.get_build_root() + 'bin/').abspath)
if not dev.is_win32():
	dev.env.Append(RPATH = env.Literal('\\$$ORIGIN'))

dev.boost_date_time = dev.build('boost/libs/date_time/src/')
dev.boost_system = dev.build('boost/libs/system/src/')

env.Append(LIBS = ['aboost_system', 'aboost_date_time'])

dev.adchpp = dev.build('adchpp/')

dev.build('adchppd/')

# Lua for plugins & swig
dev.build('lua/')

# Library wrappers
dev.build('swig/')

# Plugins
for plugin in env['plugins']:
	dev.build('plugins/' + plugin + '/')

if env['docs']:
	asciidoc_cmd = dev.get_asciidoc()
	if asciidoc_cmd is None:
		print 'asciidoc not found, docs won\'t be built'

	else:
		env['asciidoc_cmd'] = asciidoc_cmd
		def asciidoc(target, source, env):
			env.Execute(env['asciidoc_cmd'] + ' -o"' + str(target[0]) + '" "' + str(source[0]) + '"')

		doc_path = '#/build/docs/'

		env.Command(doc_path + 'readme.html', '#/readme.txt', asciidoc)

		guide_path = '#/docs/user_guide/'
		env.Command(doc_path + 'user_guide/basic_guide.html', guide_path + 'basic_guide.txt', asciidoc)
		env.Command(doc_path + 'user_guide/novice_guide.html', guide_path + 'novice_guide.txt', asciidoc)
		env.Command(doc_path + 'user_guide/images', guide_path + 'images', Copy('$TARGET', '$SOURCE'))

