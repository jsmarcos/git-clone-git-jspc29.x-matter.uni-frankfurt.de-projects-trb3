set terminal pdf
set output "hist.pdf"

set xlabel "Fine-Time"
set ylabel "Hits"
set key left
set xrange[0:511]

plot \
   "hist.txt" u 1 w lines title "Timing Trg (Trb)", \
   "hist.txt" u 4 w lines title "Timing Trg (CBM)"
#   "hist.txt" u 2 w lines title "Pulser", \
#   "hist.txt" u 3 w lines title "DLM", \
#   , \
#   "hist.txt" u 5 w lines title "External"

set output "calib.pdf"

set ylabel "Time in ns"

set yrange [-0.1 : 5.1]

plot \
   "calib.txt" u 1 w lines title "Timing Trg (Trb)", \
   "calib.txt" u 2 w lines title "Pulser", \
   "calib.txt" u 3 w lines title "DLM", \
   "calib.txt" u 4 w lines title "Timing Trg (CBM)", \
   "calib.txt" u 5 w lines title "External"   
   
   
set output "jitter.pdf"

set ylabel "Offset in ns"
set xlabel "Events"
set xrange [*:*]
set yrange [*:*]

plot "jitter.txt" u 3 w linespoints title "CBM TS - (TDC(TimingTrg@CBM) - TDC(Tinimg@Trb))"

set output "timing_trigger.pdf"
set xlabel "Events"
set ylabel "Time in ns"
plot \
   "timing_trigger.txt" u 1 w  linespoints title "Timing Trigger (Trb)", \
   "timing_trigger.txt" u 2 w  linespoints title "Timing Trigger (CBM)"

set output "timing_trigger_delta.pdf"
plot \
   "timing_trigger_delta.txt" u 1 w  linespoints title "Timing Trigger (CBM-Trb)"
   
   
