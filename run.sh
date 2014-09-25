#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log
MEM_REF_LOG="$TFOLD/din"

[ -e $LACKEY_LOG ] || mkfifo $LACKEY_LOG
[ -e $META_ROB_LOG ] || mkfifo $META_ROB_LOG

[ -e "$MEM_REF_LOG"1 ] || mkfifo "$MEM_REF_LOG"1
[ -e "$MEM_REF_LOG"2 ] || mkfifo "$MEM_REF_LOG"2
[ -e "$MEM_REF_LOG"3 ] || mkfifo "$MEM_REF_LOG"3
[ -e "$MEM_REF_LOG"4 ] || mkfifo "$MEM_REF_LOG"4

valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes $@ &

#-c number of cores; -s merged/minimum code block size; -d reorder-buffer depth
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG &
#luajit exe_blk.lua $META_ROB_LOG &
luajit cache.lua $META_ROB_LOG "$MEM_REF_LOG"1 "$MEM_REF_LOG"2 "$MEM_REF_LOG"3 "$MEM_REF_LOG"4 &
./dinero.sh < "$MEM_REF_LOG"1 > $TFOLD/miss1 &
./dinero.sh < "$MEM_REF_LOG"2 > $TFOLD/miss2 &
./dinero.sh < "$MEM_REF_LOG"3 > $TFOLD/miss3 &
./dinero.sh < "$MEM_REF_LOG"4 > $TFOLD/miss4 

