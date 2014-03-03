#!/bin/bash

find . -name "*regsync*.eps" | xargs rm 

for f in *regsync*.log; do
# set yr [0:250]
gnuplot <<EOF
load "plot_common.p"

set ylabel "Reg Sync Push per Inst"
set output "${f}.push.eps"
plot "$f" using 1:5 title "Reg Sync Push per Inst" with lines lt 1

EOF

done

for f in *regsync*.log; do
# set yr [0:250]
gnuplot <<EOF
load "plot_common.p"

set ylabel "Reg Sync Pull per Inst"
set output "${f}.pull.eps"
plot "$f" using 1:7 title "Reg Sync Pull per Inst" with lines lt 1

EOF

done
