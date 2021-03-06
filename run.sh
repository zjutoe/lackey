#!/bin/bash

TFOLD="/tmp/$(basename $1).$$"
mkdir -p $TFOLD

LACKEY_LOG="$TFOLD/lackey".log
LACKEY_LOG2="$TFOLD/lackey".log
META_ROB_LOG="$TFOLD/meta_rob".log
META_ROB_LOG2="$TFOLD/meta_rob".log2
MEM_REF_LOG="$TFOLD/din"

[ -e $LACKEY_LOG ] || mkfifo $LACKEY_LOG
[ -e $LACKEY_LOG2 ] || mkfifo $LACKEY_LOG2
[ -e $META_ROB_LOG ] || mkfifo $META_ROB_LOG
[ -e $META_ROB_LOG2 ] || mkfifo $META_ROB_LOG2

[ -e "$MEM_REF_LOG"1 ] || mkfifo "$MEM_REF_LOG"1
[ -e "$MEM_REF_LOG"2 ] || mkfifo "$MEM_REF_LOG"2
[ -e "$MEM_REF_LOG"3 ] || mkfifo "$MEM_REF_LOG"3
[ -e "$MEM_REF_LOG"4 ] || mkfifo "$MEM_REF_LOG"4

touch  $TFOLD/miss1  $TFOLD/miss2  $TFOLD/miss3  $TFOLD/miss4 
[ -e $TFOLD/miss1 ] || mkfifo $TFOLD/miss1
[ -e $TFOLD/miss2 ] || mkfifo $TFOLD/miss2
[ -e $TFOLD/miss3 ] || mkfifo $TFOLD/miss3
[ -e $TFOLD/miss4 ] || mkfifo $TFOLD/miss4


valgrind --log-file=$LACKEY_LOG --tool=lackey --trace-mem=yes --trace-superblocks=yes $@ &

#-c number of cores; -s merged/minimum code block size; -d reorder-buffer depth
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG > $META_ROB_LOG &

luajit cache.lua $META_ROB_LOG "$MEM_REF_LOG"1 "$MEM_REF_LOG"2 "$MEM_REF_LOG"3 "$MEM_REF_LOG"4 &
./dinero.sh < "$MEM_REF_LOG"1 | grep ^miss | tee > $TFOLD/miss1 &
./dinero.sh < "$MEM_REF_LOG"2 | grep ^miss | tee > $TFOLD/miss2 &
./dinero.sh < "$MEM_REF_LOG"3 | grep ^miss | tee > $TFOLD/miss3 &
./dinero.sh < "$MEM_REF_LOG"4 | grep ^miss | tee > $TFOLD/miss4 &

valgrind --log-file=$LACKEY_LOG2 --tool=lackey --trace-mem=yes --trace-superblocks=yes $@ &
luajit meta_rob.lua -c4 -s50 -d64 < $LACKEY_LOG2 > $META_ROB_LOG2 &
luajit exe_blk.lua  $META_ROB_LOG2 $TFOLD/miss1 $TFOLD/miss2 $TFOLD/miss3 $TFOLD/miss4

