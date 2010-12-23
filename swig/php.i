%begin%{
// prevent PHP's includes from tempering with ours by including adchpp.h before everything else
#include <adchpp/adchpp.h>
%}

%module php_adchpp

%include "adchpp.i"
