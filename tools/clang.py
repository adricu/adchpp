# This file is executed when setting up the environment for clang.

# Chances are very high it won't work for you! This is just a set-up for the clang 3.0 currently
# provided by Cygwin to make use of MinGW includes and generate Cygwin-free binaries.

# Feel free to modify as needed for your platform (and provide a patch? ;)).

import SCons.Tool.mingw

def generate(env):
	SCons.Tool.mingw.generate(env)

	prev_escape = env['ESCAPE']
	env['ESCAPE'] = lambda s: prev_escape(s).replace('\\', '/')

	env['CC'] = 'clang'
	env['CXX'] = 'clang'
	env.Append(CPPFLAGS = ['-nostdinc', '-U__llvm__', '-U__clang__', '-U__CYGWIN__', '-U__CYGWIN32__', '-U__GNUC_MINOR__', '-Wno-attributes', '-Wno-macro-redefined', '-Wno-format-invalid-specifier'])
	env.Append(CPPDEFINES = ['__GNUC_MINOR__=6', # clang advertises GCC 4.2; make it look like 4.6
		'_WIN32', '__MINGW32__', '__MSVCRT__', '__declspec=__declspec'])
	env.Append(CPPPATH = ['C:/MinGW/lib/gcc/mingw32/4.6.2/include/c++', 'C:/MinGW/lib/gcc/mingw32/4.6.2/include/c++/mingw32', 'C:/MinGW/lib/gcc/mingw32/4.6.2/include/c++/backward', 'C:/MinGW/lib/gcc/mingw32/4.6.2/include', 'C:/MinGW/include', 'C:/MinGW/lib/gcc/mingw32/4.6.2/include-fixed'])

	env['LINK'] = 'g++'
	env['AR'] = 'ar'
	env['RANLIB'] = 'ranlib'

def exists(env):
	return env.WhereIs('clang') is not None and Scons.Tool.mingw.exists(env)
