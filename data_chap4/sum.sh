#!/bin/bash

echo "configure speedup speedup_deep" > $1.dat

for size in 0 50 100; do
    for core in 16 64 256; do
	for depth in 16 64 256; do
	    speedup=$(grep speedup $1_regsync_c"$core"_s"$size"_d"$depth"_log | rev | cut -f1 -d: | rev)
	    speedupD=$(grep speedup $1_regsync_c"$core"_s"$size"_d"$depth"_D_log | rev | cut -f1 -d: | rev)
	    echo c"$core"_s"$size"_d"$depth" $speedup $speedupD >> $1.dat
	done
    done    
done


# #valgrind --tool=lackey --log-file=$LOGDIR/pipe --trace-mem=yes --trace-superblocks=yes $@

# | split -a 4 -b 512M - $LOGDIR/log

#date > $LOGDIR/time.end
