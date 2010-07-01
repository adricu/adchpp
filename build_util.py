import glob
import sys
import os

class Dev:
	def __init__(self, mode, tools, env):

		self.mode = mode
		self.tools = tools
		self.env = env

		self.build_root = '#/build/' + self.mode + '-' + self.tools
		if env['arch'] != 'x86':
			self.build_root += '-' + env['arch']
		self.build_root += '/'

	def prepare(self):
		if not self.env['verbose']:
			self.env['CCCOMSTR'] = "Compiling $TARGET (static)"
			self.env['SHCCCOMSTR'] = "Compiling $TARGET (shared)"
			self.env['CXXCOMSTR'] = "Compiling $TARGET (static)"
			self.env['SHCXXCOMSTR'] = "Compiling $TARGET (shared)"
			self.env['PCHCOMSTR'] = "Compiling $TARGET (precompiled header)"
			self.env['GCHCOMSTR'] = "Compiling $TARGET (static precompiled header)"
			self.env['GCHSHCOMSTR'] = "Compiling $TARGET (shared precompiled header)"
			self.env['SHLINKCOMSTR'] = "Linking $TARGET (shared)"
			self.env['LINKCOMSTR'] = "Linking $TARGET (static)"
			self.env['ARCOMSTR'] = "Archiving $TARGET"
			self.env['RCCOMSTR'] = "Resource $TARGET"
		
		self.env.SConsignFile()
		self.env.SetOption('implicit_cache', '1')
		self.env.SetOption('max_drift', 60*10)
		self.env.Decider('MD5-timestamp')

		if 'mingw' in self.env['TOOLS']:
			self.env.Append(LINKFLAGS=["-Wl,--enable-runtime-pseudo-reloc"])

			if sys.platform != 'win32':
				if self.env.get('prefix') is not None:
					prefix = self.env['prefix']
				else:
					prefix = 'i386-mingw32-'
				self.env['CC'] = prefix + 'gcc'
				self.env['CXX'] = prefix + 'g++'
				self.env['LINK'] = prefix + 'g++'
				self.env['AR'] = prefix + 'ar'
				self.env['RANLIB'] = prefix + 'ranlib'
				self.env['RC'] = prefix + 'windres'
				self.env['PROGSUFFIX'] = '.exe'
				self.env['LIBPREFIX'] = 'lib'
				self.env['LIBSUFFIX'] = '.a'
				self.env['SHLIBSUFFIX'] = '.dll'

	def is_win32(self):
		return sys.platform == 'win32' or 'mingw' in self.env['TOOLS']

	def get_build_root(self):
		return self.build_root

	def get_build_path(self, source_path):
		return self.get_build_root() + source_path

	def get_target(self, source_path, name, in_bin = True):
		if in_bin:
			return self.get_build_root() + 'bin/' + name
		else:
			return self.get_build_root() + source_path + name

	def get_sources(self, source_path, source_glob):
		return map(lambda x: self.get_build_path(source_path) + x, glob.glob(source_glob))

	def prepare_build(self, source_path, name, source_glob = '*.cpp', in_bin = True,
			precompiled_header = None, shared_precompiled_header = None):
		env = self.env.Clone()
		env.BuildDir(self.get_build_path(source_path), '.', duplicate = 0)

		sources = self.get_sources(source_path, source_glob)

		if precompiled_header is not None or shared_precompiled_header is not None:
			if shared_precompiled_header is None:
				pch = precompiled_header
			else:
				pch = shared_precompiled_header

			for i, source in enumerate(sources):
				if source.find(pch + '.cpp') != -1:
					# the PCH/GCH builder will take care of this one
					del sources[i]

			if env['CC'] == 'cl': # MSVC
				env['PCHSTOP'] = pch + '.h'
				env['PCH'] = env.PCH(self.get_target(source_path, pch + '.pch', False), pch + '.cpp')[0]

			elif 'gcc' in env['TOOLS']:
				if shared_precompiled_header is None:
					gch_tool = 'Gch'
				else:
					gch_tool = 'GchSh'
				exec "env['" + gch_tool + "'] = env." + gch_tool + "(self.get_target(source_path, pch + '.gch', False), pch + '.h')[0]"

		return (env, self.get_target(source_path, name, in_bin), sources)

	def build(self, source_path, local_env = None):
		if not local_env:
			local_env = self.env
		full_path = local_env.Dir('.').path + '/' + source_path	
		return local_env.SConscript(source_path + 'SConscript', exports={'dev' : self, 'source_path' : full_path })

	def i18n (self, source_path, buildenv, sources, name):
		if self.env['mode'] != 'release' and not self.env['i18n']:
			return

		p_oze = glob.glob('po/*.po')
		languages = [ os.path.basename(po).replace ('.po', '') for po in p_oze ]
		potfile = 'po/' + name + '.pot'
		buildenv['PACKAGE'] = name
		ret = buildenv.PotBuild(potfile, sources)

		for po_file in p_oze:
			buildenv.Precious(buildenv.PoBuild(po_file, [potfile]))
			lang = os.path.basename(po_file)[:-3]
			mo_file = self.get_target(source_path, "locale/" + lang + "/LC_MESSAGES/" + name + ".mo", True)
			buildenv.MoBuild (mo_file, po_file)

#		for lang in languages:
#			modir = (os.path.join (install_prefix, 'share/locale/' + lang + '/LC_MESSAGES/'))
#			moname = domain + '.mo'
#			installenv.Alias('install', installenv.InstallAs (os.path.join (modir, moname), lang + '.mo'))
		return ret

	# support installs that only have an asciidoc.py file but no executable
	def get_asciidoc(self):
		if 'PATHEXT' in self.env['ENV']:
			pathext = self.env['ENV']['PATHEXT'] + ';.py'
		else:
			pathext = ''
		asciidoc = self.env.WhereIs('asciidoc', pathext = pathext)
		if asciidoc is None:
			return None
		if asciidoc[-3:] == '.py':
			if self.env.WhereIs('python') is None:
				return None
			asciidoc = 'python ' + asciidoc
		return asciidoc

def CheckPKGConfig(context, version):
	context.Message( 'Checking for pkg-config... ' )
	ret = context.TryAction('pkg-config --atleast-pkgconfig-version=%s' % version)[0]
	context.Result( ret )
	return ret

def CheckPKG(context, name):
	context.Message( 'Checking for %s... ' % name )
	ret = context.TryAction('pkg-config --exists "%s"' % name)[0]
	if ret:
		context.env.ParseConfig('pkg-config --cflags --libs "%s"' % name)

	context.Result( ret )
	return ret

def array_remove(array, to_remove):
	if to_remove in array:
		array.remove(to_remove)
