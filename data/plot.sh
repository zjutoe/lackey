#!/bin/bash

find . -name "*.eps" | xargs rm 

for f in *_log; do
# set yr [0:250]
gnuplot <<EOF
load "plot_common.p"

set ylabel "Reg Sync per Inst"
set output "${f}.eps"
plot "$f" using 1:5 title "Reg Sync per Inst" with lines lt 1

EOF

gnuplot <<EOF
load "plot_common.p"

set ylabel "Reg R/W per Inst"
set output "${f}_rw.eps"
plot "$f" using 1:8 title "Reg R/W per Inst" with lines lt 1

EOF

done


