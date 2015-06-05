//
//  CircularBuffer.h
//  OpenSpirometry
//
//  Created by Eric Larson on 6/1/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//
//  Modified from:
// Copyright (c) 2012 Alex Wiltschko
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

#define kMaxNumChannels 4

@interface CircularBuffer : NSObject

@property (nonatomic, readonly) SInt64 numChannels;

//designated intializer
-(id)initWithNumChannels:(SInt64)numChannels andBufferSize:(SInt64)bufferLength;

-(void) seekWriteHeadPositionWithOffset:(SInt64) offset andChannel: (int) iChannel;
-(void) seekReadHeadPositionWithOffset:(SInt64) offset andChannel:(int) iChannel;

-(SInt64) numNewFramesFromLastReadFrame:(SInt64) lastReadFrame withChannel: (int) iChannel;
-(SInt64) numUnreadFramesForChannel:(int) iChannel;
-(SInt64) numUnreadFrames;

-(void) addNewFloatData:(float *)newData withNumSamples:(SInt64) numFrames
              toChannel:(SInt64) whichChannel;
-(void) addNewFloatData:(float *)newData withNumSamples:(SInt64) numFrames;

-(void) fetchData:(float *)outData withNumSamples:(SInt64)numFrames andOutputStride:(SInt64) stride
       forChannel:(SInt64) whichChannel;
-(void) fetchData:(float *)outData withNumSamples:(SInt64)numFrames;

-(void) fetchFreshData:(float *)outData withNumSamples:(SInt64) numFrames andOutputStride:(SInt64) stride
            forChannel:(SInt64) whichChannel;
-(void) fetchFreshData:(float *)outData withNumSamples:(SInt64) numFrames;

-(void) addNewInterleavedFloatData:(float *)newData withNumSamples:(SInt64) numFrames withNumChannels:(SInt64) numChannelsHere;
-(void) fetchInterleavedData:(float *)outData withNumSamples:(SInt64)numFrames;


//void AddNewSInt16Data(const SInt16 *newData, const SInt64 numFrames, const SInt64 whichChannel);
//void AddNewDoubleData(const double *newData, const SInt64 numFrames, const SInt64 whichChannel = 0);
//
//SInt64 WriteHeadPosition(int aChannel = 0) { return mLastWrittenIndex[aChannel]; }
//SInt64 ReadHeadPosition(int aChannel = 0) { return mLastReadIndex[aChannel]; }


-(void) Clear;

// Analytics
-(float) meanOfChannel:(SInt64) channel;
-(float) maxOfChannel:(SInt64) channel;
-(float) minOfChannel:(SInt64) channel;

@end
