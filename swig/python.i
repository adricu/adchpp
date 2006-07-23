%module pyadchpp

%{
// Python pollution
#undef socklen_t
%}

%include "adchpp.i"
