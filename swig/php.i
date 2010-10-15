%begin%{
// prevent PHP's includes from tempering with this by including it before everything else
#include <iostream>
%}

%module php_adchpp

%include "adchpp.i"
