//
//  PeakFinder.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>

// helper class for the analysis (used like a struct, but allows ARC and Obj-C objects)
@interface Peak : NSObject

@property (nonatomic) NSUInteger index;
@property (nonatomic) float frequency;
@property (strong, nonatomic) NSMutableArray *harmonics;
@property (nonatomic) NSUInteger multiple;
@property (nonatomic) float magnitude;

@end

@interface PeakFinder : NSObject

-(id)initWithFrequencyResolution:(float)res;

-(NSArray*)getFundamentalPeaksFromBuffer:(float *)magBuffer
                              withLength:(NSUInteger)length
                         usingWindowSize:(NSUInteger)windowSize
                 andPeakMagnitudeMinimum:(float)peakMagnitude
                          aboveFrequency:(float)minimumFrequency;

- (float)getFrequencyFromIndex:(NSUInteger)index
                          usingData:(float*)data;

@end


