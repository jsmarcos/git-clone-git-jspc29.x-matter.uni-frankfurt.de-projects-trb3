import struct
import datetime
import numpy as np

def eventIterator(f):
   f.seek(0)
   pos = 0
   
   while(1):
      # we might need to skip some padding
      assert(f.tell() <= pos)
      f.seek(pos)
      
      evtHdrBuf = f.read(8*4)
      if (len(evtHdrBuf) != 8*4):
         break #eof
   
      hdr = struct.unpack("<" + ("I" * 8), evtHdrBuf)
      if (hdr[1] > 0xf0000): hdr = struct.unpack(">" + ("I" * 8), evtHdrBuf)
      
      evtSize = hdr[0]
      
      pos += evtSize
      if (evtSize % 8):
         pos += 8 - (evtSize % 8)
      
      # decode hdr
      hdrDec = {
         'size': evtSize,
         'triggerType': hdr[2] & 0xffff,
         'evtNumFile': hdr[3],
         'timestamp': datetime.datetime(
                        (hdr[4] >> 16) & 0xff, (hdr[4] >> 8) & 0xff, (hdr[4] >> 0) & 0xff, 
                        (hdr[5] >> 16) & 0xff, (hdr[5] >> 8) & 0xff, (hdr[5] >> 0) & 0xff ),
         'runNum': hdr[6]
      }
      
      # load payload
      subEvents = []
      innerPos = 8*4
      while(innerPos < evtSize):
         subEvtHdrBuf = f.read(4 * 4)
         endian = "<"
         subEvtHdr = struct.unpack("<" + ("I" * 4), subEvtHdrBuf)
         if (subEvtHdr[1] > 0xf0000):
            subEvtHdr = struct.unpack(">" + ("I" * 4), subEvtHdrBuf)
            endian = ">"
         
         subEvtSize = subEvtHdr[0]
         subEvtHdrDec = {
            'size': subEvtSize,
            'subEvtId': subEvtHdr[2] & 0xffff,
            'trgNum': (subEvtHdr[3] >> 8) & 0xffffff,
            'trgCode': subEvtHdr[3] & 0xff
         }
         
         subsubEvents = []
         ssPos = 4*4
         while(ssPos < subEvtSize):
            sseHdrBuf = f.read(4)
            sseHdr = struct.unpack(endian + "I", sseHdrBuf)
            sseSize = ((sseHdr[0] >> 16) & 0xffff) * 4 
            sseHdrDec = {
               'size': sseSize,
               'subsubEvtId': sseHdr[0] & 0xffff
            }
            
            sseBuf = f.read(sseSize)
            sseCont = struct.unpack(endian + ("I" * (sseSize/4)), sseBuf)
            subsubEvents.append( (sseHdrDec, sseCont) )
            
            ssPos += sseSize + 4
         
         subEvents.append( (subEvtHdrDec, subsubEvents) )
         
         innerPos += subEvtSize
         
      yield (hdrDec, subEvents)

def dumpEvt(evt):
   res = str(evt[0]) + "\n"
   for subEvt in evt[1]:
      res += "  " + dumpSubEvt(subEvt).replace("\n", "\n  ") + "\n"
   return res

def dumpSubEvt(sEvt):
   h = sEvt[0]
   res = "subEvtId: 0x%04x, trgNum: % 9d, trgCode: % 4d, size: % 4d\n" % (h['subEvtId'], h['trgNum'], h['trgCode'], h['size'])
   for ssEvt in sEvt[1]:
      res += "  " + dumpSubSubEvt(ssEvt).replace("\n", "\n  ") + "\n"
   return res

def dumpSubSubEvt(ssEvt):
   res = "ID: 0x%04x, Size: %d\n" % (ssEvt[0]['subsubEvtId'], ssEvt[0]['size'])
   res += dumpArray(ssEvt[1])
   return res

def dumpArray(arr):
   res = ""
   for i in range(0, len(arr)):
      if i != 0 and i % 8 == 0: res += "\n"
      res += "  [% 3d] 0x%08x" % (i+1, arr[i])

   return res


def extractCTS(ssEvtData):
   hdr = ssEvtData[0]
   length = 1 + \
      ((hdr >> 16) & 0xf) * 2 + \
      ((hdr >> 20) & 0x1f) * 2 + \
      ((hdr >> 25) & 0x1) * 2 + \
      ((hdr >> 26) & 0x1) * 3 + \
      ((hdr >> 27) & 0x1) * 1

   if (((hdr >> 28) & 0x3) == 0x1): length += 1
   if (((hdr >> 28) & 0x3) == 0x2): length += 4

   return (ssEvtData[:length], ssEvtData[length:])

def extractSync(ssEvtData):
   hdr = ssEvtData[0]
   assert(hdr >> 28 == 0x1)
   packType = (hdr >> 26) & 0x3
   length = 1
   if (packType == 1): length += 4
   if (packType == 3): length += 10
   
   return (ssEvtData[:length], ssEvtData[length:])


def extractTDC(ssEvtData):
   length = ssEvtData[0]
   assert(length >= len(ssEvtData))
   return (ssEvtData[:length+1], ssEvtData[length:])   

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


