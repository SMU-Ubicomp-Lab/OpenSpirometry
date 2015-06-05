//
//  PeakFinder.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "PeakFinder.h"
#import <Accelerate/Accelerate.h>




@implementation Peak

-(id)initWithIndex:(NSUInteger)index andMagnitude:(float)mag andFreq:(float)freq{
    if(self = [super init]){
        _index = index;
        _harmonics = [[NSMutableArray alloc]init];
        _frequency = freq;
        _multiple = 1;
        _magnitude = mag;
        return self;
    }
    return nil;
}

@end

@interface PeakFinder()

@property (nonatomic) float frequencyResolution;

@end

@implementation PeakFinder

-(id)initWithFrequencyResolution:(float)res{
    if(self = [super init]){
        _frequencyResolution = res;
        return self;
    }
    return nil;
}


// Use dilation to find local max peaks (use harmonics to refine the peak estimation)
// Using starter code from Candie Solis, Charlie Albright, and Spencer Kaiser, MSLC 2015
// this returns an array of peaks fundamental frequencies in the spectrum (if any)
//      return type: index, frequency, magnitude, and list of harmonics
-(NSArray*)getFundamentalPeaksFromBuffer:(float *)magBuffer
                              withLength:(NSUInteger)length
                         usingWindowSize:(NSUInteger)windowSize
                 andPeakMagnitudeMinimum:(float)peakMagnitude
                          aboveFrequency:(float)minimumFrequency
{
    NSMutableArray* peaks = [[NSMutableArray alloc] init];
    int startIndex = minimumFrequency / self.frequencyResolution; // must be above X Hz
    
    for (int i = startIndex; i < length-windowSize; i++) {
        unsigned long mid = (i + windowSize/2);
        
        // find maximum of spectrum in window
        //  (this is a nested for loop, but parallelized in hardware)
        float maxValue;
        unsigned long maxIndex;
        vDSP_maxvi(&(magBuffer[i]), 1, &maxValue, &maxIndex, windowSize);
        maxIndex += i;
        
        if ((maxValue > peakMagnitude) && (mid == maxIndex)) { // Local max AND large enough magnitude
            
            Peak *peakFound = [[Peak alloc]initWithIndex:mid
                                            andMagnitude:maxValue
                                                 andFreq:[self getFrequencyFromIndex:mid usingData:magBuffer]];

            if ([peaks count] == 0) { // nothing to check, just add in
                
                [peaks addObject:peakFound];
            }
            else {  // Check if harmonic multiple exists below the peak
                
                BOOL unique = YES;
                
                for (Peak* peakInPeaks in peaks) {
                    NSUInteger numVal = peakInPeaks.index; // index of peak
                    NSUInteger multiple = mid / numVal; // integer value of harmonic multiple
                    NSUInteger modulus = mid % numVal;  // num frequency bins above multiple
                    if (modulus > numVal/multiple) {
                        modulus = numVal - modulus; // num frequency bins below multiple, if closer
                        multiple++; // multiple is next harmonic up
                    }
                    float freqInHzAway = self.frequencyResolution * modulus; // deviation in Hz from harmonic (1 Hz tolerance)
                    
                    if (freqInHzAway <= self.frequencyResolution * multiple) { // scale difference by harmonic multiple (to account for mis-estimation of the fundamental up to 1Hz)
                        unique = false;
                        peakFound.multiple = multiple; // remember the multiple
                        [peakInPeaks.harmonics addObject:peakFound];
                        
                        break; // found least common multiple and it is within deviation, add it in
                    }
                }
                
                if (unique) { // it was not a harmonic
                    [peaks addObject:peakFound];
                }
            }
        }
    }
    
    if ([peaks count] == 0) {
        return nil;
    }
    else {
        // go through and fix the frequencies
        for (Peak* peak in peaks){
            if([peak.harmonics count]>0){ // only fundamental, just add in
                float frequency = peak.frequency;
                int numFrequenciesToAverage = 1;
                for(Peak *harmonic in peak.harmonics){
                    frequency += (harmonic.frequency / ((float)harmonic.multiple));
                    numFrequenciesToAverage++;
                }
                peak.frequency= frequency/((float)numFrequenciesToAverage);
            }
        }
        
        NSArray* returnArraySortedByMagnitude = [peaks sortedArrayUsingComparator:
                                                 ^NSComparisonResult(Peak* a, Peak* b) {
                                                     return a.magnitude<b.magnitude;
                                                 }];
        
        return returnArraySortedByMagnitude; // largest magnitude first
    }
}

// Uses quadratic interpolation to estimate the peak frequency given an index and the array of FFT magnitude data from which it was calculated
// Implementation by Story Zanetti, Jessica Yeh, and Jordan Kayse, MSLC 2015
- (float)getFrequencyFromIndex:(NSUInteger)index
                          usingData:(float*)data
{
    if (index == 0) {
        return 0;
    }
    
    float f2 = index * self.frequencyResolution;
    float m1 = data[index - 1];
    float m2 = data[index];
    float m3 = data[index + 1];
    
    return f2 + ((m3 - m2) / (2.0 * m2 - m1 - m2)) * self.frequencyResolution / 2.0;
}



@end
