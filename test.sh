#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log
OOO_LOG="$TFOLD/ooo".log
MEM_REF_LOG="$TFOLD/mtrace".log
COHERENCE_LOG="$TFOLD/ca_coherence".log
SHARED_L1_LOG="$TFOLD/ca_shared_L1".log
SWB_LOG="$TFOLD/ca_swb".log
EXE_PARA_LOG="$TFOLD/exe_para".log


export LUA_PATH="./cache/?.lua;./cache/config/?.lua;;"

valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes --detailed-counts=yes $@
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG 
#luajit ooo.lua $META_ROB_LOG > $OOO_LOG
luajit mtrace.lua $META_ROB_LOG >$MEM_REF_LOG
luajit cache/ca_coherence.lua < $MEM_REF_LOG > $COHERENCE_LOG
luajit cache/ca_shared_L1.lua < $MEM_REF_LOG > $SHARED_L1_LOG
luajit cache/test_swb.lua < $MEM_REF_LOG > $SWB_LOG
luajit exe_parallel.lua < $MEM_REF_LOG > $EXE_PARA_LOG
