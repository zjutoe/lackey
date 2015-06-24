#!/bin/bash

for t in ~/doc/paper/p_shared_L1/data/cpu2006_log/*.bin; do
    ./exe_parallel.sh $t/meta_rob.log;
done
