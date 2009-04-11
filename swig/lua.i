%module luadchpp

typedef unsigned int size_t;

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

	lua_pushvalue(L, 1); /* pass error message */
	lua_pushinteger(L, 2); /* skip this function and traceback */
	lua_call(L, 2, 1); /* call debug.traceback */
	return 1;
}

class RegistryItem : private boost::noncopyable {
public:
	RegistryItem(lua_State* L_) : L(L_), index(luaL_ref(L, LUA_REGISTRYINDEX)) {
	}
	~RegistryItem() {
		luaL_unref(L, LUA_REGISTRYINDEX, index);
	}

	void push() { lua_rawgeti(L, LUA_REGISTRYINDEX, index); }
private:
	lua_State* L;
	int index;
};

class LuaFunction {
public:
	LuaFunction(lua_State* L_) : L(L_), registryItem(new RegistryItem(L_)) { }
	LuaFunction(const LuaFunction& rhs) : L(rhs.L), registryItem(rhs.registryItem) { }
	LuaFunction& operator=(const LuaFunction& rhs) { L = rhs.L; registryItem = rhs.registryItem; return *this; }

	void operator()() {
		pushFunction();
		docall(0, 0);
	}

	void operator()(adchpp::Entity& c) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		docall(1, 0);
	}

	void operator()(adchpp::Entity& c, const std::string& str) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		lua_pushstring(L, str.c_str());

		docall(2, 0);
	}

	void operator()(adchpp::Entity& c, int i) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		lua_pushinteger(L, i);

		docall(2, 0);
	}

	void operator()(adchpp::Entity& c, adchpp::AdcCommand& cmd) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		SWIG_NewPointerObj(L, &cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);

		docall(2, 0);
	}

	void operator()(adchpp::Entity& c, adchpp::AdcCommand& cmd, bool& i) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		SWIG_NewPointerObj(L, &cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);
		lua_pushboolean(L, i);

		if(docall(3, 1) != 0) {
			return;
		}


		if(lua_isboolean(L, -1)) {
			i &= lua_toboolean(L, -1) == 1;
		}
		lua_pop(L, 1);
	}

	void operator()(const adchpp::SimpleXML& s) {
		pushFunction();

		SWIG_NewPointerObj(L, &s, SWIGTYPE_p_adchpp__SimpleXML, 0);
		docall(1, 0);
	}

	void operator()(adchpp::Entity& c, const adchpp::StringList& cmd, bool& i) {
		pushFunction();

		SWIG_NewPointerObj(L, &c, SWIGTYPE_p_adchpp__Entity, 0);
		SWIG_NewPointerObj(L, &cmd, SWIGTYPE_p_std__vectorT_std__string_t, 0);
		lua_pushboolean(L, i);

		if(docall(3, 1) != 0) {
			return;
		}

		if(lua_isboolean(L, -1)) {
			i &= lua_toboolean(L, -1) == 1;
		}
		lua_pop(L, 1);
	}


private:
	void pushFunction() { registryItem->push(); }

	int docall(int narg, int nret) {
		int status;
		int base = lua_gettop(L) - narg;  /* function index */
		lua_pushcfunction(L, traceback);  /* push traceback function */
		lua_insert(L, base);  /* put it under chunk and args */
		status = lua_pcall(L, narg, nret, base);
		lua_remove(L, base);  /* remove traceback function */
		if(status == LUA_ERRRUN) {
			if (!lua_isnil(L, -1)) {
				const char *msg = lua_tostring(L, -1);
				if (msg == NULL) msg = "(error object is not a string)";
				fprintf(stderr, "%d, %d: %s\n", status, lua_type(L, -1), msg);
			} else {
				fprintf(stderr, "Lua error without error");
			}
			lua_pop(L, 1);
		} else if(status == LUA_ERRMEM) {
			fprintf(stderr, "Lua memory allocation error\n");
		} else if(status == LUA_ERRERR) {
			fprintf(stderr, "Lua error function error\n");
		} else if(status != 0) {
			fprintf(stderr, "Unknown lua status: %d\n", status);
		}

		return status;
	}

	lua_State* L;
	std::tr1::shared_ptr<RegistryItem> registryItem;
};

%}

%typemap(in, checkfn="lua_isnumber") int64_t,uint64_t,const int64_t&, const uint64_t& {
	$1 = ($1_ltype)lua_tonumber(L,$input);
}
%typemap(out) int64_t,uint64_t,const int64_t&, const uint64_t& {
   lua_pushnumber(L, (lua_Number)$1); SWIG_arg++;
}

%typemap(in) std::tr1::function<void () > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &, adchpp::AdcCommand &) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &, adchpp::AdcCommand &, bool&) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &, int) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &, const std::string&) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (const SimpleXML&) > {
	$1 = LuaFunction(L);
}

%typemap(in) std::tr1::function<void (adchpp::Entity &, const adchpp::StringList&, bool&) > {
	$1 = LuaFunction(L);
}

%include "adchpp.i"

%extend adchpp::AdcCommand {
	std::string getParam(const char* name, size_t start) {
		std::string tmp;
		if(self->getParam(name, start, tmp)) {
			return tmp;
		}
		return std::string();
	}
}
