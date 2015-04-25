#!/bin/bash

inputs="\
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/astar_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/bzip2_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/gcc_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/gobmk_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/h264ref_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/hmmer_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/lbm_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/libquantum_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/mcf_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/milc_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/namd_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/omnetpp_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/perlbench_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/povray_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/sjeng_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/soplex_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/specrand_base.amd64-m64-gcc46-3.bin/mtrace.log \
/Users/toe/doc/paper/p_shared_L1/data/cpu2006_log/sphinx_livepretend_base.amd64-m64-gcc46-3.bin/mtrace.log \
"

for input in $inputs; do
    D=$(dirname $input)
    luajit ca_swb.lua < $input > $D/swb.log
    luajit ca_coherence.lua < $input > $D/coherence.log
done
