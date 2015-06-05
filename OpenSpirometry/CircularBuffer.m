//
//  CircularBuffer.m
//  OpenSpirometry
//
//  Created by Eric Larson on 6/1/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
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


#import "CircularBuffer.h"

@interface CircularBuffer()
{
    SInt64 mLastWrittenIndex[kMaxNumChannels];
    SInt64 mLastReadIndex[kMaxNumChannels];
    SInt64 mNumUnreadFrames[kMaxNumChannels];
}

@property (nonatomic, readwrite) SInt64 numChannels;
@property (nonatomic) float **mData;
@property (nonatomic) SInt64 sizeOfBuffer;

@end


@implementation CircularBuffer

#pragma mark Initialization and Dealloc
//designated initializer for the ringbuffer
-(id)initWithNumChannels:(SInt64)numChannels
           andBufferSize:(SInt64)bufferLength {
    
    if(self = [super init]){
        self.sizeOfBuffer = bufferLength;
        if (numChannels > kMaxNumChannels)
            self.numChannels = kMaxNumChannels;
        else if (numChannels <= 0)
            self.numChannels = 1;
        else
            self.numChannels = numChannels;
        
        self.mData = (float **)calloc((long)numChannels, sizeof(float *));
        for (int i=0; i < numChannels; ++i) {
            self.mData[i] = (float *)calloc((long)bufferLength, sizeof(float));
            self->mLastWrittenIndex[i] = 0;
            self->mLastReadIndex[i] = 0;
            self->mNumUnreadFrames[i] = 0;
        }
        
        return self;
    }
    
    return nil;
}

-(void) dealloc{
    for (int i=0; i<self.numChannels; i++) {
        free(self.mData[i]);
    }
    free(self.mData);
    self.mData = nil;
}

#pragma mark Add Float Data
-(void) addNewFloatData:(float *)newData
         withNumSamples:(SInt64) numFrames
              toChannel:(SInt64) whichChannel
{
    
    SInt64 idx;
    for (int i=0; i < numFrames; ++i) {
        idx = (i + self->mLastWrittenIndex[whichChannel]) % (self.sizeOfBuffer);
        self.mData[whichChannel][idx] = newData[i];
    }
    
    mLastWrittenIndex[whichChannel] = (mLastWrittenIndex[whichChannel] + numFrames) % (self.sizeOfBuffer);
    mNumUnreadFrames[whichChannel] = mNumUnreadFrames[whichChannel] + numFrames;
    if (mNumUnreadFrames[whichChannel] >= self.sizeOfBuffer) mNumUnreadFrames[whichChannel] = self.sizeOfBuffer;
}

-(void) addNewFloatData:(float *)newData
         withNumSamples:(SInt64) numFrames
{
    [self addNewFloatData:newData
           withNumSamples:numFrames
                toChannel:0];
}

-(void) addNewInterleavedFloatData:(float *)newData
                    withNumSamples:(SInt64) numFrames
                   withNumChannels:(SInt64) numChannelsHere
{
    
    int numChannelsToCopy = (numChannelsHere <= self.numChannels) ? (int)numChannelsHere : (int)self.numChannels;
    float zero = 0.0f;
    
    for (int iChannel = 0; iChannel < numChannelsToCopy; ++iChannel) {
        
        if (numFrames + mLastWrittenIndex[iChannel] < self.sizeOfBuffer) { // if our new set of samples won't overrun the edge of the buffer
            vDSP_vsadd((float *)&newData[iChannel],
                       (long)numChannelsHere,
                       &zero,
                       &self.mData[iChannel][mLastWrittenIndex[iChannel]],
                       1,
                       (unsigned long)numFrames);
        }
        
        else {															// if we will overrun, then we need to do two separate copies.
            int numSamplesInFirstCopy = (int)(self.sizeOfBuffer - mLastWrittenIndex[iChannel]);
            int numSamplesInSecondCopy = (int)(numFrames - numSamplesInFirstCopy);
            
            vDSP_vsadd((float *)&newData[iChannel],
                       (long)numChannelsHere,
                       &zero,
                       &self.mData[iChannel][mLastWrittenIndex[iChannel]],
                       1,
                       numSamplesInFirstCopy);
            
            vDSP_vsadd((float *)&newData[numSamplesInFirstCopy*numChannelsHere + iChannel],
                       (long)numChannelsHere,
                       &zero,
                       &self.mData[iChannel][0],
                       1,
                       numSamplesInSecondCopy);
        }
        
        mLastWrittenIndex[iChannel] = (mLastWrittenIndex[iChannel] + numFrames) % (self.sizeOfBuffer);
        mNumUnreadFrames[iChannel] = (mNumUnreadFrames[iChannel] + numFrames);
        if (mNumUnreadFrames[iChannel] >= self.sizeOfBuffer) mNumUnreadFrames[iChannel] = self.sizeOfBuffer;
    }
    
    
}

#pragma mark Access Float Data

-(void) fetchFreshData:(float *)outData
        withNumSamples:(SInt64) numFrames
       andOutputStride:(SInt64) stride
            forChannel:(SInt64) whichChannel
{
    
    if (mLastWrittenIndex[whichChannel] - numFrames >= 0) { // if we're requesting samples that won't go off the left end of the ring buffer, then go ahead and copy them all out.
        
        UInt32 idx = (UInt32)(mLastWrittenIndex[whichChannel] - numFrames);
        float zero = 0.0f;
        vDSP_vsadd(&self.mData[whichChannel][idx],
                   1,
                   &zero,
                   outData,
                   (long)stride,
                   (unsigned long)numFrames);
    }
    
    else { // if we will overrun, then we need to do two separate copies.
        
        // The copy that bleeds off the left, and cycles back to the right of the ring buffer
        int numSamplesInFirstCopy = (int)(numFrames - mLastWrittenIndex[whichChannel]);
        // The copy that starts at the beginning, and proceeds to the end.
        int numSamplesInSecondCopy = (int)(mLastWrittenIndex[whichChannel]);
        
        
        float zero = 0.0f;
        UInt32 firstIndex = (UInt32)(self.sizeOfBuffer - numSamplesInFirstCopy);
        vDSP_vsadd(&self.mData[whichChannel][firstIndex],
                   1,
                   &zero,
                   &outData[0],
                   (long)stride,
                   numSamplesInFirstCopy);
        
        vDSP_vsadd(&self.mData[whichChannel][0],
                   1,
                   &zero,
                   &outData[numSamplesInFirstCopy*stride],
                   (long)stride,
                   numSamplesInSecondCopy);
        
    }
    
}

-(void) fetchFreshData:(float *)outData
        withNumSamples:(SInt64) numFrames
{
    [self fetchFreshData:outData
          withNumSamples:numFrames
          andOutputStride:1
              forChannel:0];
}

-(void) fetchData:(float *)outData
         withNumSamples:(SInt64) numFrames
         andOutputStride:(SInt64) stride
             forChannel:(SInt64) whichChannel
{
    int idx;
    for (int i=0; i < numFrames; ++i) {
        idx = (int)((mLastReadIndex[whichChannel] + i) % (self.sizeOfBuffer));
        outData[i*stride] = self.mData[whichChannel][idx];
    }
    
    mLastReadIndex[whichChannel] = (mLastReadIndex[whichChannel] + numFrames) % (self.sizeOfBuffer);
    
    mNumUnreadFrames[whichChannel] -= numFrames;
    if (mNumUnreadFrames[whichChannel] <= 0) mNumUnreadFrames[whichChannel] = 0;
    
}

-(void) fetchData:(float *)outData
   withNumSamples:(SInt64) numFrames
{
    [self fetchData:outData
     withNumSamples:numFrames
     andOutputStride:1
         forChannel:0];
    
}

-(void) fetchInterleavedData:(float *)outData
              withNumSamples:(SInt64) numFrames
{
    for (int iChannel=0; iChannel < self.numChannels; ++iChannel) {
        [self fetchData:&outData[iChannel]
         withNumSamples:numFrames
         andOutputStride:self.numChannels
             forChannel:iChannel];
    }
    
}


#pragma mark Offset Access
-(void) seekWriteHeadPositionWithOffset:(SInt64) offset
                             andChannel: (int) iChannel
{
    self->mLastWrittenIndex[iChannel] = (self->mLastWrittenIndex[iChannel] + offset) % (self.sizeOfBuffer);
}

-(void) seekReadHeadPositionWithOffset:(SInt64) offset
                            andChannel:(int) iChannel
{
    self->mLastReadIndex[iChannel] = (self->mLastReadIndex[iChannel] + offset) % (self.sizeOfBuffer);
}


-(SInt64) numNewFramesFromLastReadFrame:(SInt64) lastReadFrame
                            withChannel: (int) iChannel
{
    int numNewFrames = (int)(self->mLastWrittenIndex[iChannel] - lastReadFrame);
    if (numNewFrames < 0) numNewFrames += self.sizeOfBuffer;
    
    return (SInt64)numNewFrames;
}

-(SInt64) numUnreadFramesForChannel:(int) iChannel
{
    return mNumUnreadFrames[iChannel];
}

-(SInt64) numUnreadFrames
{
    return [self numUnreadFramesForChannel:0];
}


#pragma mark - Analytics
-(float) meanOfChannel:(SInt64) channel
{
    float mean;
    vDSP_meanv(self.mData[channel],1,&mean,(unsigned long)self.sizeOfBuffer);
    return mean;
}


-(float) maxOfChannel:(SInt64) channel
{
    float mean;
    vDSP_maxv(self.mData[channel],1,&mean,(unsigned long)self.sizeOfBuffer);
    return mean;
}


-(float) minOfChannel:(SInt64) channel
{
    float mean;
    vDSP_minv(self.mData[channel],1,&mean,(unsigned long)self.sizeOfBuffer);
    return mean;
}

-(void)Clear
{
    for (int i=0; i < self.numChannels; ++i) {
        memset(self.mData[i], 0, sizeof(float)*((unsigned long)self.sizeOfBuffer));
        self->mLastWrittenIndex[i] = 0;
        self->mLastReadIndex[i] = 0;
    }
    
}

@end
