import datetime
import glob
from hldLib import *
import numpy as np

def tdcTimeData(w):
   if not (w & 0x80000000):
      return None
   
   return {
      "coarseTime": (w >> 0) & 0x7ff,
      "edge": (w >> 11) & 1,
      "fineTime": (w >> 12) & 0x3ff,
      "channelNo": (w >> 22) & 0x7f
   }

thresh = -1
counter = 0
TDCCHANS = 5

files = glob.glob("/u/mpenschuck/*.hld")
files.sort()
files.pop()
print "# Read file ", files[-1]

hits = np.zeros( (TDCCHANS,2,1024) ).astype(int)
hitTimes = np.zeros( TDCCHANS ).astype("double")

invChan = 0

with open(files[-1], "rb") as hld:
   for evt in eventIterator(hld):
      for sEvt in evt[1]:
         #print dumpEvt(evt)
         for ssEvt in sEvt[1]:
            if ssEvt[0]['subsubEvtId'] == 0xf3c0:
               cts, remain = extractCTS(ssEvt[1])
               sync, tdc = extractSync(remain)
               #tdc, remain = extractTDC(remain)
               assert(len(sync) in {1, 5, 11})
               
               if 0:
                  print "CTS:  ", dumpArray(cts)
                  print "Sync: ", dumpArray(sync)
                  print "TDC:  ", dumpArray(tdc)

               for w in tdc:
                  if w & 0x80000000:
                     tdcData = tdcTimeData(w)
                     if not tdcData: continue
                     #print tdcData["channelNo"]
                     if tdcData["channelNo"] < TDCCHANS:
                        hits[tdcData["channelNo"], tdcData["edge"], tdcData["fineTime"]] += 1
                     else:
                        invChan += 1
                     
                  elif (w >> 29) == 1: # tdc header
                     #assert( (w >> 16) & 0xff == evt[0]['trgCode'] )
                     #print "hdr"
                     pass
                     

      counter += 1
      if thresh > 0 and thresh <= counter:
         break

print "#Processed: %d events" % counter
print "#Found %d valid and %d invalid hits: %s" % (np.sum(hits), invChan, ", ".join(["(chan: %d, fall: %d, rise: %d)" % (i, np.sum(hits[i,0,:]), np.sum(hits[i,1,:])) for i in range(TDCCHANS)])) 

calibInNs = np.cumsum(hits[:,1,:], axis=1).astype('double') / (np.sum(hits[:,1,:], axis=1)[:,np.newaxis] + 1e-100)
calibInNs[:-1] += 0.5 * (calibInNs[1:]-calibInNs[:-1])
calibInNs *= 5.0 / np.max(calibInNs, axis=1)[:,np.newaxis]
np.save("calib.dat", calibInNs)

np.savetxt("hist.txt", hits[:,1,:].T, fmt='%d')
np.savetxt("calib.txt", calibInNs.T)