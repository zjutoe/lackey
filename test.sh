#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log
OOO_LOG="$TFOLD/ooo".log
MEM_REF_LOG="$TFOLD/mtrace".log
COHERENCE_LOG="$TFOLD/coherence".log


valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes --detailed-counts=yes $@ 
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG 
#luajit ooo.lua $META_ROB_LOG > $OOO_LOG
luajit mtrace.lua $META_ROB_LOG >$MEM_REF_LOG
luajit coherence.lua < $MEM_REF_LOG > $COHERENCE_LOG
