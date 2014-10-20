set terminal pdf
set output "time_between_events_hist.pdf"

load "time_between_events.label"
set label labelText at graph 0.05,0.95


binwidth=10
bin(x,width)=width*floor(x/width)
plot 'time_between_events.txt' using (bin($2*1000,binwidth)):(1.0) smooth freq with boxes notitle