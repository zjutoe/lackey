#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log
OOO_LOG="$TFOLD/ooo".log
MEM_REF_LOG="$TFOLD/din"


valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes --detailed-counts=yes $@ 
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG 
luajit ooo.lua $META_ROB_LOG > $OOO_LOG