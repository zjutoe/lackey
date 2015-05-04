#!/bin/bash

dinero_param="-l1-isize 8k -l1-dsize 8k -l1-ibsize 16 -l1-dbsize 16 -l1-iassoc 2 -l1-dassoc 2 -l1-irepl l -l1-drepl l -l1-ifetch d -l1-dfetch d -l1-dwalloc a -l1-dwback a -flushcount 10k -stat-idcombine -informat d"
dinero="../../DineroIV/d4-7/dineroIV"

#luajit main.lua | tee >(grep ^1 | cut -d' ' -f2- > test/cpu1.trace ) >(grep ^2 | cut -d' ' -f2- > test/cpu2.trace) >(grep ^3 | cut -d' ' -f2- > test/cpu3.trace) >(grep ^4 | cut -d' ' -f2- > test/cpu4.trace)

# luajit mrb_private_L1.lua -c4 -s50 -d64 < date.log | \
#     tee >(grep ^1 | cut -d' ' -f2- | $dinero $dinero_param > test/cpu1.dinero)  \
#     >(grep ^2 | cut -d' ' -f2- | $dinero $dinero_param > test/cpu2.dinero) \
#     >(grep ^3 | cut -d' ' -f2- | $dinero $dinero_param > test/cpu3.dinero) \
#     >(grep ^4 | cut -d' ' -f2- | $dinero $dinero_param > test/cpu4.dinero) \
#     >(grep -v \# | cut -d' ' -f2- | $dinero $dinero_param > test/cpu0.dinero) \

luajit mrb_private_L1.lua -c4 -s50 -d64 < date.log > test/date_rob.log
grep ^1 test/date_rob.log | cut -d' ' -f2- | $dinero $dinero_param | grep ^miss > test/cpu1.dinero
grep ^2 test/date_rob.log | cut -d' ' -f2- | $dinero $dinero_param | grep ^miss > test/cpu2.dinero
grep ^3 test/date_rob.log | cut -d' ' -f2- | $dinero $dinero_param | grep ^miss > test/cpu3.dinero
grep ^4 test/date_rob.log | cut -d' ' -f2- | $dinero $dinero_param | grep ^miss > test/cpu4.dinero
