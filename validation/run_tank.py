from pathlib import Path
import ctypes
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
state=lib.luaL_newstate()
lib.luaL_openlibs(state)
try:
    result=lib.luaL_loadstring(state,Path('validation/tank.lua').read_bytes())
    if not result: result=lib.lua_pcallk(state,0,0,0,0,None)
    if result: raise RuntimeError(lib.lua_tolstring(state,-1,None).decode())
    print('PASS: tank regressions, all 28 class/tree profiles, ranks, cooldown forecasts, AoE switching, settings registration, secrecy and missing APIs')
finally:
    lib.lua_close(state)
