%module adchpp

%{
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

%include "adchpp.i"
