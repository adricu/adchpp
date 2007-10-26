import glob
import sys

class Dev:
	def __init__(self, mode, tools, env):
		
		self.mode = mode
		self.tools = tools
		self.env = env
	
	def prepare(self):
		if not self.env['verbose']:
			self.env['CCCOMSTR'] = "Compiling $TARGET (static)"
			self.env['SHCCCOMSTR'] = "Compiling $TARGET (shared)"
			self.env['CXXCOMSTR'] = "Compiling $TARGET (static)"
			self.env['SHCXXCOMSTR'] = "Compiling $TARGET (shared)"
			self.env['SHLINKCOMSTR'] = "Linking $TARGET (shared)"
			self.env['LINKCOMSTR'] = "Linking $TARGET (static)"
			self.env['ARCOMSTR'] = "Archiving $TARGET"
			self.env['RCCOMSTR'] = "Resource $TARGET"
		
		self.env.SConsignFile()
		self.env.SetOption('implicit_cache', '1')
		self.env.SetOption('max_drift', 60*10)

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

	def get_build_root(self):
		return '#/build/' + self.mode + '-' + self.tools + '/'

	def get_build_path(self, source_path):
		return self.get_build_root() + source_path
	
	def get_target(self, source_path, name, in_bin = True):
		if in_bin:
			return self.get_build_root() + 'bin/' + name
		else:
			return self.get_build_root() + source_path + name
		
	def get_sources(self, source_path, source_glob):
		return map(lambda x: self.get_build_path(source_path) + x, glob.glob(source_glob))
		
	def prepare_build(self, source_path, name, source_glob = '*.cpp', in_bin = True):
		local_env = self.env.Copy()
		
		local_env.BuildDir(self.get_build_path(source_path), '.', duplicate = 0)
		
		return (local_env, self.get_target(source_path, name, in_bin), self.get_sources(source_path, source_glob))

	def build(self, source_path, local_env = None):
		if not local_env:
			local_env = self.env
		full_path = local_env.Dir('.').path + '/' + source_path	
		return local_env.SConscript(source_path + 'SConscript', exports={'dev' : self, 'source_path' : full_path })

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
	   
