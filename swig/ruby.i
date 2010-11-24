%module rbadchpp
%feature("autodoc", "3");

%runtime%{
// ruby pollution
#undef connect
#undef bind
#undef accept
#undef sleep
#undef Sleep
#undef shutdown
#undef send
#undef listen
%}

%wrapper%{

class RbFunction {
public:
	RbFunction(VALUE obj) : obj(obj) { }

	VALUE call(VALUE v0) { return rb_funcall(obj, swig_call_id, 1, v0); }
	VALUE call(VALUE v0, VALUE v1) { return rb_funcall(obj, swig_call_id, 2, v0, v1); }
	VALUE call(VALUE v0, VALUE v1, VALUE v2) { return rb_funcall(obj, swig_call_id, 3, v0, v1, v2); }

	void operator()() {
		rb_funcall(obj, swig_call_id, 0);
	}

	void operator()(adchpp::Entity& c) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		call(v0);
	}

	void operator()(adchpp::Entity& c, const std::string& str) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		auto v1 = SWIG_From_std_string(str);

		call(v0, v1);
	}

	void operator()(adchpp::Entity& c, int i) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		auto v1 = SWIG_From_int(i);

		call(v0, v1);
	}

	void operator()(adchpp::Entity& c, adchpp::AdcCommand& cmd) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		auto v1 = SWIG_NewPointerObj(&cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);

		call(v0, v1);
	}

	void operator()(adchpp::Entity& c, adchpp::AdcCommand& cmd, bool& i) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		auto v1 = SWIG_NewPointerObj(&cmd, SWIGTYPE_p_adchpp__AdcCommand, 0);
		auto v2 = i ? Qtrue : Qfalse;

		auto ret = call(v0, v1, v2);
		i &= ret != Qfalse;
	}

	void operator()(const adchpp::SimpleXML& s) {
		auto v0 = SWIG_NewPointerObj((void*)&s, SWIGTYPE_p_adchpp__SimpleXML, 0);
		call(v0);
	}

	void operator()(adchpp::Entity& c, const std::vector<std::string>& cmd, bool& i) {
		auto v0 = SWIG_NewPointerObj(&c, SWIGTYPE_p_adchpp__Entity, 0);
		auto v1 = SWIG_NewPointerObj((void*)&cmd, SWIGTYPE_p_std__vectorT_std__string_std__allocatorT_std__string_t_t, 0);
		auto v2 = i ? Qtrue : Qfalse;

		auto ret = call(v0, v1, v2);
		i &= ret != Qfalse;
	}

	void operator()(adchpp::Bot& bot, const adchpp::BufferPtr& buf) {
		auto v0 = SWIG_NewPointerObj(&bot, SWIGTYPE_p_adchpp__Bot, 0);
		auto v1 = SWIG_NewPointerObj((void*)&buf, SWIGTYPE_p_adchpp__BufferPtr, 0);

		call(v0, v1);
	}

private:
	swig::GC_VALUE obj;
};

%}

%typemap(in) std::function<void (adchpp::Entity &) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Entity &, adchpp::AdcCommand &) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Entity &, adchpp::AdcCommand &, bool&) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Entity &, int) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Entity &, const std::string&) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (const SimpleXML&) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Entity &, const adchpp::StringList&, bool&) > {
	$1 = RbFunction($input);
}

%typemap(in) std::function<void (adchpp::Bot&, const adchpp::BufferPtr&) > {
	$1 = RbFunction($input);
}

%include "adchpp.i"
