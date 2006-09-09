%module luadchpp

%{
namespace adchpp {
	class Client;
	class AdcCommand;
};

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

static int docall (lua_State *L, int narg, int nret) {
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

class LuaFunction {
public:
	LuaFunction(lua_State* L_) : L(L_), index(luaL_ref(L, LUA_REGISTRYINDEX)) { }
	LuaFunction(const LuaFunction& rhs) : L(rhs.L), index(rhs.index) { }
	LuaFunction& operator=(const LuaFunction& rhs) { L = rhs.L; index = rhs.index; return *this; }
	
	/** @todo Fix deref */

	template<typename T0>	
	void operator()(const T0&) {
		printf("Calling 1...\n");
	}
	template<typename T0, typename T1>
	void operator()(const T0&, const T1&) {
		printf("Calling 2...\n");
	}
	void operator()(adchpp::Client& c, adchpp::AdcCommand& cmd, int& i) {
		printf("Calling 3...\n");
		lua_rawgeti(L, LUA_REGISTRYINDEX, index);
		
		SWIG_NewPointerObj(L,&c,SWIGTYPE_p_adchpp__Client,0);
		SWIG_NewPointerObj(L,&cmd,SWIGTYPE_p_adchpp__AdcCommand,0);
		lua_pushinteger(L, i);
		
		docall(L, 3, 0);
		
	}

private:
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
