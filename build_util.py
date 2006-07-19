import glob

class Dev:
	def __init__(self, mode, tools, env):
		self.mode = mode
		self.tools = tools
		self.env = env
		
	def get_build_root(self):
		return '#/build/' + self.mode + '-' + self.tools + '/'

	def get_build_path(self, source_path):
		return self.get_build_root() + source_path
	
	def get_target(self, source_path, name):
		return self.get_build_root() + 'bin/' + name
		
	def get_sources(self, source_path, source_glob):
		return map(lambda x: self.get_build_path(source_path) + x, glob.glob(source_glob))
		
	def prepare_build(self, source_path, name, source_glob = '*.cpp'):
		local_env = self.env.Copy()
		
		local_env.BuildDir(self.get_build_path(source_path), '.', duplicate = 0)
		
		return (local_env, self.get_target(source_path, name), self.get_sources(source_path, source_glob))

	def build(self, source_path, local_env = None):
		if not local_env:
			local_env = self.env
		full_path = local_env.Dir('.').path + '/' + source_path	
		return local_env.SConscript(source_path + 'SConscript', exports={'dev' : self, 'source_path' : full_path })
