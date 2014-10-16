import datetime
import glob
from hldLib import *
import numpy as np

def slopeWithoutAvg(X):
   slope = X[1:]-X[:-1]
   return slope - np.average(slope)

def slope(X):
   return X[1:] - X[:-1]

def tdcTimeData(w):
   if not (w & 0x80000000):
      return None
   
   return {
      "coarseTime": (w >> 0) & 0x7ff,
      "edge": (w >> 11) & 1,
      "fineTime": (w >> 12) & 0x3ff,
      "channelNo": (w >> 22) & 0x7f
   }

thresh = 150
counter = 0
TDCCHANS = 5

files = glob.glob("/u/mpenschuck/*.hld")
files.sort()

epoch = 0
epochTimeInNs = 0.0

calibDataTDC = np.load("calib.dat.npy")

firstEpoch = -1
events = []

with open(files[-1], "rb") as hld:
   lastEvent = None
   for evt in eventIterator(hld):
      if not len(evt[1]): continue
      
      event = {
         'trgCode': evt[1][0][0]['trgCode'],
         'sync': None,
         'hits': [[] for i in range(TDCCHANS)]
      }

      for sEvt in evt[1]:
         for ssEvt in sEvt[1]:
            if ssEvt[0]['subsubEvtId'] == 0xf3c0:
               cts, remain = extractCTS(ssEvt[1])
               sync, tdc = extractSync(remain)
               assert(len(sync) in {1, 5, 11})
               
               event['sync'] = sync
               
               if lastEvent:
                  for w in tdc:
                     if w & 0x80000000:
                        tdcData = tdcTimeData(w)
                        if tdcData["edge"] == 1 and tdcData["channelNo"] < TDCCHANS and tdcData["fineTime"] != 0x3ff:
                           fineTimeInNs = calibDataTDC[tdcData["channelNo"], tdcData["fineTime"]]
                           assert( 0 <= fineTimeInNs <= 5.0 )
                           coarseTimeInNs = tdcData["coarseTime"] * 5.0
                           lastEvent['hits'][ tdcData["channelNo"] ].append( coarseTimeInNs - fineTimeInNs + epochTimeInNs )
                           #if tdcData["channelNo"] in {0,3}: print tdcData, fineTimeInNs, coarseTimeInNs - fineTimeInNs
                     
                     elif (w >> 29) == 3: # epoch counter
                        epoch = w & 0x0fffffff
                        if firstEpoch < 0:
                           firstEpoch = epoch
                        epochTimeInNs = (epoch - firstEpoch) * 10240.0 
                        
                     elif (w >> 29) == 1: # tdc header
                        if (w >> 16) & 0xff != lastEvent['trgCode']:
                           break
                        
                     elif (w >> 29) == 2: # debug
                        pass
                     else:
                        print "Unknown TDC word type: 0x%08x" % w

      if lastEvent and lastEvent['sync'] != None and len(lastEvent['hits'][0]) == 1 and len(lastEvent['hits'][3]) == 1:
         events.append(lastEvent)
         
      lastEvent = event
      
      counter += 1
      if thresh > 0 and thresh <= counter:
         break

cbmEvtTimestamps = np.array( [1.0*evt['sync'][2] for evt in events] ) 
cbmEvtTimestamps[1:] = np.cumsum(  cbmEvtTimestamps[1:] - cbmEvtTimestamps[:-1] ) * 8.0
cbmEvtTimestamps[0] = 0.0

trbEvtTimestamps = np.array( [1.0*evt['sync'][1] for evt in events] ) 
trbEvtTimestamps[1:] = np.cumsum(  trbEvtTimestamps[1:] - trbEvtTimestamps[:-1] ) * 10.0
trbEvtTimestamps[0] = 0.0

factor = np.average( slope(trbEvtTimestamps) / slope(cbmEvtTimestamps) )

tdcTrbRefTimestamp = np.array( [evt['hits'][0][0] for evt in events] ) * factor
tdcCbmRefTimestamp = np.array( [evt['hits'][3][0] for evt in events] ) * factor
timestampDelta = tdcCbmRefTimestamp - tdcTrbRefTimestamp

offset=0
if offset > 0:
   cbmEvtTimestamps = cbmEvtTimestamps[offset:]
   timestampDelta = timestampDelta[:-offset]
elif offset < 0:
   timestampDelta = timestampDelta[-offset:]
   cbmEvtTimestamps = cbmEvtTimestamps[:offset]
   

timestamps = cbmEvtTimestamps - timestampDelta + timestampDelta[0]

interval = timestamps[1:] - timestamps[:-1]

print "Std of interval", np.std(interval)



plotData = np.vstack([ slopeWithoutAvg(cbmEvtTimestamps), slopeWithoutAvg(timestampDelta), slope(timestamps) ])
np.savetxt("jitter.txt", plotData.T)

pulserTS = np.array( [ p for evt in events for p in evt['hits'][1]] )
pulserInterval = pulserTS[1:] - pulserTS[:-1]

#np.savetxt("timing_trigger.txt", np.vstack([slope(tdcTrbRefTimestamp), slope(tdcCbmRefTimestamp)]).T)

np.savetxt("timing_trigger.txt", np.vstack([slope(tdcTrbRefTimestamp), slope(tdcCbmRefTimestamp)]).T)
np.savetxt("timing_trigger_delta.txt", np.vstack([timestampDelta]).T)
