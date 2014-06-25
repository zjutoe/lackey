#reset
set autoscale                        # scale axes automatically
unset log                              # remove any log-scaling
unset label                            # remove any previous labels 
set xtic rotate by -45                 # set xtics easier to read
set ytic auto                          # set ytics automatically
#set auto x
set terminal postscript enhanced mono dashed lw 1 "Helvetica" 16 eps
set size 1,0.65
#size 300,300
#set terminal postscript  enhanced color eps   

#set term png truecolor

set style data histogram
set output "ls.eps"
#set xlabel "Configure"
set ylabel "Speedup"
#set grid
set boxwidth 1 relative
set style fill solid 1.0 border

#plot for [COL=2:3] "sum_spec2006_regpull.tex" using COL:xticlabels(1) title columnheader
#plot for [COL=2:3] "sum_spec2006_regpull.tex" using COL title columnheader
   
plot "ls.dat" using 2:xticlabels(1) fs solid 1 title col, '' using 3 fill pattern 4 title col;

#set ylabel "Improvement with Affinity Aware Schedule"
set output "date.eps"
   plot "date.dat" using 2:xticlabels(1) fs solid 1 title col, '' using 3 fill pattern 4 title col;
   
