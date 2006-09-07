%module pyadchpp

%{
// Python pollution
#undef socklen_t
%}

%typemap(in) boost::function<void (adchpp::Client&)> {
	$1 = PyHandle($input);
}

%include "adchpp.i"

%init%{
	PyEval_InitThreads();
%}
%{
struct PyGIL {
	PyGIL() { state = PyGILState_Ensure(); }
	~PyGIL() { PyGILState_Release(state); }
	PyGILState_STATE state;
};

struct PyHandle {
	PyHandle(PyObject* obj_) : obj(obj_) { Py_XINCREF(obj); }
	PyHandle(const PyHandle& rhs) : obj(rhs.obj) { Py_XINCREF(obj); }
	
	PyHandle& operator=(const PyHandle& rhs) { 
		Py_XDECREF(obj);
		obj = rhs.obj;
		Py_XINCREF(obj);
		return *this;
	}
	~PyHandle() { Py_XDECREF(obj); }
	
	operator PyObject*() { return obj; }
	
	void operator()() {
		PyGIL gil;
		PyHandle ret(PyObject_Call(obj, PyTuple_New(0), 0));
	}
	
	void operator()(Client& t) {
		PyGIL gil;
		PyObject* args(PyTuple_New(1));
		
		PyTuple_SetItem(args, 0, swig::from(&t));
//		PyTuple_SetItem(args, 0, SWIG_NewPointerObj(SWIG_as_voidptr(&t), SWIGTYPE_p_adchpp__Client, 0 |  0 ));
		PyHandle ret(PyObject_Call(obj, args, 0));
	}
	
private:
	PyObject* obj;
};
%}



