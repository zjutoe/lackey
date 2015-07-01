#!/bin/bash

IN=$1
OUT=$(dirname $IN)/exe_parallel.log

export LUA_PATH="./cache/?.lua;./cache/config/?.lua;;"
luajit exe_parallel.lua < $IN > $OUT


