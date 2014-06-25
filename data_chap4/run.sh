#!/bin/bash

#DIR=/home/toe/cpu2006/benchspec/CPU2006/401.bzip2/exe
#BIN=bzip2_base.i386-m32-gcc44-3.bin
#LOGDIR=tests/log/$1
LOGDIR=data_chap4

mkdir -p $LOGDIR
# [ -e $LOGDIR/pipe ] || mkfifo $LOGDIR/pipe

# date > $LOGDIR/time.start

for size in 0 50 100; do
    for core in 16 64 256; do
	for depth in 16 64 256; do
	    luajit mrb_share_L1.lua -c$core -s$size -d$depth < $1.log > $LOGDIR/$1_regsync_c"$core"_s"$size"_d"$depth"_log
	    luajit mrb_share_L1.lua -D -c$core -s$size -d$depth < $1.log > $LOGDIR/$1_regsync_c"$core"_s"$size"_d"$depth"_D_log
	done
    done    
done


# #valgrind --tool=lackey --log-file=$LOGDIR/pipe --trace-mem=yes --trace-superblocks=yes $@

# | split -a 4 -b 512M - $LOGDIR/log

#date > $LOGDIR/time.end
