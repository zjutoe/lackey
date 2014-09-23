#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log

[ -e $LACKEY_LOG ] || mkfifo $LACKEY_LOG
[ -e $META_ROB_LOG ] || mkfifo $META_ROB_LOG

valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes $@ &

luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG &
luajit exe_blk.lua $META_ROB_LOG

