#!/usr/bin/env python2.7
import numpy as np
import pylab as plt
import scipy as sp
import scipy.signal as sps
import scipy.ndimage.filters as spf
import sys

def extractChannels(frame):
   defs = [[255, 251, 15], [15, 251, 15], [255,3,255], [15, 251, 255]]

   channels = []
   for de in defs:
      fc = frame.copy()
      for col in range(3):
	 d = de[col]
	 if d < 128:
	    fc[...,col] = fc[...,col] < (100)
	 else:
	    fc[...,col] = fc[...,col] > (150)
      
      channels.append(255 * fc[...,0] * fc[...,1] * fc[...,2])

   return [spf.gaussian_filter(ch, 3) for ch in channels]

def getYValues(ch):
   return np.argmax(ch, axis=0)

def getLocMax(func):
   data = func.copy()
   m = np.max(data)
   data = data * (data > 0.8*m)
   data = np.convolve(data, sps.gaussian(31, 5), mode='same')

   wx = 100
   x = 0
   while(x < data.shape[0]):
      sub = data[x:x+wx]
      idx = np.argmax(sub)
      sub[:], sub[idx] = 0, sub[idx]
      x += np.max([1, idx])
   
   nz = np.nonzero(data)
   return nz[0]
   
def computePhases(fn, geo):
   img = plt.imread(fn)
   img = (255.0 * img / np.max(img)).astype('uint8')
   frame = img[geo[0]:geo[1],geo[2]:geo[3],:]

   chs = extractChannels(frame)
   lms = []
   pers = np.zeros( 4 )
   for i, ch in zip(range(4), chs):
      data = getYValues(ch)
      lm   = getLocMax(data)
      assert(len(lm) > 1)
      lms.append(lm)
      pers[i] = (np.average(lm[1:] - lm[:-1]))
      
   period = np.average(pers)
   assert((((pers - period) / period) ** 2 < 1e-3).all())

   phases = np.array([np.average( lm - period * np.array(range(len(lm))) ) / period for lm in lms ])
   phases -= phases[0]
   phases[phases < 0] += 1
   phases -= phases.astype(int)
   
   return phases

fn = sys.argv[1]
val = computePhases(fn, [48,366,75,874])
if len(val) == 4:
   print "ok, phase: ", val
else:
   print "fail"
   






