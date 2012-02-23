# This file is executed when setting up the environment for the Clang Static Analyzer.

import clang

def generate(env):
	clang.generate(env)

	env['CC'] = 'scan-build ' + env['CC']
	env['CXX'] = 'scan-build ' + env['CXX']

def exists(env):
	return env.WhereIs('scan-build') is not None and clang.exists(env)
