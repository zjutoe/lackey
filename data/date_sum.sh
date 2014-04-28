echo -n > date_sum.tex

for s in 0 50 100; do
    for c in 16 64; do
	for d in 16 64 256; do
	    rspi=$(tail -n1 date_regsync_c"$c"_s"$s"_d"$d"_log | cut -f3 -d:| awk '{print $1}')
	    echo -n "$rspi & " >> date_sum.tex
	done
    done
    echo "\\\\" >> date_sum.tex
done

for s in 0 50 100; do
    for c in 16 64; do
	for d in 16 64 256; do
	    rspi=$(tail -n1 date_regsync_c"$c"_s"$s"_d"$d"_a_log | cut -f3 -d:| awk '{print $1}')
	    echo -n "$rspi & " >> date_sum.tex
	done
    done
    echo "\\\\" >> date_sum.tex
done
