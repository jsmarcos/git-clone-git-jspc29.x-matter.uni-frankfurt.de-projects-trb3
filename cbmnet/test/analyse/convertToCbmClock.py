import datetime
import glob
from hldLib import *
import numpy as np

noEvents = 1000000
counter = 0
TDCCHANS = 5

files = glob.glob("/local/mpenschuck/hldfiles/*.hld")
files.sort()
files.pop()
files.pop()
#files.pop()

epoch = 0
epochTimeInNs = 0.0

calibDataTDC = np.load("calib.dat.npy")

firstEpoch = -1


trbRefTimeTDCChan = 0
cbmRefTimeTDCChan = 3

eventTimeInCBM = np.zeros( noEvents )
print "Read file ", files[-1]
with open(files[-1], "rb") as hld:
   lastEvent = None
   for evt in eventIterator(hld):
      if not len(evt[1]): continue
      
      trbTDC = None
      cbmTDC = None
      sync = None
      
      for sEvt in evt[1]:
         for ssEvt in sEvt[1]:
            if ssEvt[0]['subsubEvtId'] == 0xf3c0:
               cts, remain = extractCTS(ssEvt[1])
               sync, tdc = extractSync(remain)
               assert(len(sync) in {1, 5, 11})
               
               for w in tdc:
                  if w & 0x80000000:
                     tdcData = tdcTimeData(w)
                     if tdcData["edge"] == 1 and tdcData["channelNo"] in {trbRefTimeTDCChan, cbmRefTimeTDCChan} and tdcData["fineTime"] != 0x3ff:
                        fineTimeInNs = calibDataTDC[tdcData["channelNo"], tdcData["fineTime"]]
                        assert( 0 <= fineTimeInNs <= 5.0 )
                        coarseTimeInNs = tdcData["coarseTime"] * 5.0
                        tdcTime = coarseTimeInNs - fineTimeInNs + epochTimeInNs
                        
                        if tdcData["channelNo"] == trbRefTimeTDCChan:
                           trbTDC = tdcTime
                        else:
                           cbmTDC = tdcTime
                           
                        if trbTDC != None and cbmTDC != None: break
                  
                  elif (w >> 29) == 3: # epoch counter
                     epoch = w & 0x0fffffff
                     tmp = epoch * 10240.0 
                     if epochTimeInNs > tmp:
                        print epoch
                        #tmp += 10240.0 * 0x0fffffff
                     epochTimeInNs = tmp
                     
                  elif (w >> 29) == 1: # tdc header
                     pass
                  elif (w >> 29) == 2: # debug
                     pass
                  else:
                     print "Unknown TDC word type: 0x%08x" % w
      
      if trbTDC != None and cbmTDC != None:
         eventTimeInCBM[counter] = 8.0 * sync[2] + trbTDC - cbmTDC
      else:
         print "Bad Event: %d" % counter
         
      counter += 1
      if noEvents <= counter:
         break
      
if counter < noEvents:
   print "Only found %d events" % counter
   eventTimeInCBM = eventTimeInCBM[:counter]

#eventTimeInCBM -= eventTimeInCBM[0]
timeBetweenEvents = slope(eventTimeInCBM)

avgInterval = np.average(timeBetweenEvents)
stdInterval = np.std(timeBetweenEvents)

print "Avg: %f ns, Std: %f ns" % (avgInterval, stdInterval)

np.savetxt("time_between_events.txt", np.vstack([timeBetweenEvents, timeBetweenEvents - avgInterval]).T )

text_file = open("time_between_events.label", "w")
text_file.write('labelText = "Events: %d\\nAvg: %.2f ns\\nFreq: %.2f KHz\\nStd: %.2f ps"' % (counter, avgInterval, 1e6 / avgInterval, stdInterval * 1000) )
text_file.close()


