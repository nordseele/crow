#pragma once

#include <stm32f7xx.h>

// lua_State*
#include "../submodules/lua/src/lua.h"
#include "../submodules/lua/src/lauxlib.h"
#include "../submodules/lua/src/lualib.h"

#include "lualink.h" // ErrorHandler_t, Lua_eval(), Lua_load_default_script()

void REPL_init( lua_State* lua );
void REPL_begin_upload( void );
void REPL_upload( int flash );
void REPL_clear_script( void );
void REPL_default_script( void );
void REPL_reset( void );

void REPL_eval( char* buf, uint32_t len, ErrorHandler_t errfn );
void REPL_print_script( void );
void REPL_print_script_name( char* buffer );
