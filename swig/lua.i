%module luadchpp

%wrapper %{

static int traceback (lua_State *L) {
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
  	printf("No debug table\n");
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
  	printf("No traceback in debug\n");
    lua_pop(L, 2);
    return 1;
  }

  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
}

class LuaFunction {
public:
	LuaFunction(lua_State* L_) : L(L_), index(luaL_ref(L, LUA_REGISTRYINDEX)) { }
	LuaFunction(const LuaFunction& rhs) : L(rhs.L), index(rhs.index) { }
	LuaFunction& operator=(const LuaFunction& rhs) { L = rhs.L; index = rhs.index; return *this; }
	
	/** @todo Fix deref */

	void operator()(adchpp::Client& c) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Client, 0);
		docall(1, 0);
	}
	
	void operator()(adchpp::Client& c, const std::string& str) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Client, 0);
		lua_pushstring(L, str.c_str());
		
		docall(2, 0);
	}
	
	void operator()(adchpp::Client& c, int i) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Client, 0);
		lua_pushinteger(L, i);
		
		docall(2, 0);
	}
	
	void operator()(adchpp::Client& c, adchpp::AdcCommand& cmd) {
		pushFunction();
		
		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Client, 0);
		SWIG_NewPointerObj(L, &cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);
	
		docall(2, 0);
		
	}

	void operator()(adchpp::Client& c, adchpp::AdcCommand& cmd, int& i) {
		pushFunction();
		
		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Client, 0);
		SWIG_NewPointerObj(L, &cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);
		lua_pushinteger(L, i);
		
		docall(3, 0);
		
	}

private:

	void pushFunction() {
		lua_rawgeti(L, LUA_REGISTRYINDEX, index);
	}

	int docall(int narg, int nret) {
		int status;
		int base = lua_gettop(L) - narg;  /* function index */
		lua_pushcfunction(L, traceback);  /* push traceback function */
		lua_insert(L, base);  /* put it under chunk and args */
		status = lua_pcall(L, narg, nret, base);
		lua_remove(L, base);  /* remove traceback function */
		/* force a complete garbage collection in case of errors */
		if (status != 0) { 
			lua_gc(L, LUA_GCCOLLECT, 0);
			if (!lua_isnil(L, -1)) {
				const char *msg = lua_tostring(L, -1);
				if (msg == NULL) msg = "(error object is not a string)";
				fprintf(stderr, "%s\n", msg);
				lua_pop(L, 1);
			}
		}
		return status;
	}
	
	lua_State* L;
	int index;
};

%}

%typemap(in) boost::function<void (adchpp::Client &) > {
	$1 = LuaFunction(L);
}

%typemap(in) boost::function<void (adchpp::Client &, adchpp::AdcCommand &) > {
	$1 = LuaFunction(L);
}

%typemap(in) boost::function<void (adchpp::Client &, adchpp::AdcCommand &, int&) > {
	$1 = LuaFunction(L);
}

%include "adchpp.i"
