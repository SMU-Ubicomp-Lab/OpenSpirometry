//
//  FlowVolumeData.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "FlowVolumeDataAnalyzer.h"

@interface FlowVolumeDataAnalyzer()

@property (strong,nonatomic) NSMutableArray *constantSampledFlowInLitersPerSecond;
@property (strong,nonatomic) NSMutableArray *constantSampledVolumeInLiters;
@property (strong,nonatomic) NSMutableArray *constantSampledCumulativeTime; // negative before test beginning?

@property (strong,nonatomic) NSMutableArray *dynamicSampledFlow; // array of user entered flow rates
@property (strong,nonatomic) NSMutableArray *dynamicSampledTime; // array of media times, entered
@property (nonatomic,readwrite) BOOL isFinalized;
@property (strong, nonatomic) NSMutableDictionary *errorsInEffort; // users can add custom error tags

@end

@implementation FlowVolumeDataAnalyzer

// override designated init
-(id)init{
    if(self=[super init]){
        _isFinalized = NO;
        _errorsInEffort = [@{} mutableCopy];
        _constantSampledCumulativeTime = [@[] mutableCopy];
        _constantSampledFlowInLitersPerSecond = [@[] mutableCopy];
        _constantSampledVolumeInLiters = [@[] mutableCopy];
        
        _dynamicSampledFlow = [@[] mutableCopy];
        _dynamicSampledTime = [@[] mutableCopy];
        
        return self;
    }
    return nil;
}

#pragma mark Computed Properties
-(NSNumber*)fevOneInLiters{
    // check to see if the arrays are built out enough to calculate this, then calculate it each time asked for
    return nil;
}

-(NSNumber*)fvcInLiters{
    // only calculate if test is finalized
    return nil;
}

-(NSNumber*)peakFlowInLitersPerSecond{
    // check to see if the arrays are built out enough to calculate this, then calculate it each time asked for
    return nil;
}

-(NSNumber*)fevOneOverFvc{
    NSNumber *val = @(self.fevOneInLiters.doubleValue/self.fvcInLiters.doubleValue);
    if([val isEqualToNumber:[NSDecimalNumber notANumber]] ){
        return nil;
    }
    return val;
}

#pragma mark Add/Clear Data Functions
-(void)addFlowEstimateInLitersPerSecond:(float)flow withTimeStamp:(CFAbsoluteTime)time{
    // add flow and time
    [self.dynamicSampledFlow addObject:@(flow)];
    [self.dynamicSampledTime addObject:@(flow)];
    
    // interpolate flow and add points(s) to curve
}

-(void)addCustomErrorToEffort:(NSString *)errorMessage forKey:(NSString *)customKey{
    self.errorsInEffort[customKey] = errorMessage; // creates key if not already there
}

-(void)clearDataInEffort{
    self.isFinalized = NO;
    [self.errorsInEffort  removeAllObjects];
    [self.constantSampledCumulativeTime removeAllObjects];
    [self.constantSampledFlowInLitersPerSecond removeAllObjects];
    [self.constantSampledVolumeInLiters removeAllObjects];
    
    [self.dynamicSampledFlow removeAllObjects];
    [self.dynamicSampledTime removeAllObjects];
}

#pragma mark Query Data Functions
-(NSDictionary*)finalizeCurvesAndGetResults{
    
    //TODO: perform any filtering of the flow rate
    //TODO: add in effort error checking (after the test)
    
    // Failures:{didCough, insufficient, early stop, bad start}
    // data: flowVolume, flowTime, volumeTime, common scalar measures
    
    // all blank for now, just so you get an idea of the structure of what is returned
    return @{@"FlowCurveInLitersPerSecond":[[NSArray alloc] initWithArray:self.constantSampledFlowInLitersPerSecond], // send back nonmutable copy
             @"VolumeCurveInLiters":[[NSArray alloc] initWithArray:self.constantSampledVolumeInLiters], // send back nonmutable copy
             @"TimeStampsForFlowAndVolume":[[NSArray alloc] initWithArray:self.constantSampledCumulativeTime], // send back nonmutable copy
             @"PeakFlowInLitersPerSecond":self.peakFlowInLitersPerSecond ? self.peakFlowInLitersPerSecond:@0,
             @"FEVOneInLiters":self.fevOneInLiters ? self.fevOneInLiters:@0,
             @"FVCInLiters":self.fvcInLiters ? self.fvcInLiters:@0,
             @"FEVOneOverFVC":self.fevOneOverFvc ? self.fevOneOverFvc:@0,
             @"ErrorsDictionary":[[NSDictionary alloc] initWithDictionary:self.errorsInEffort], // send back nonmutable copy
             };
    // this returned Dictionary should be very easy to save as JSON for developers and users
}

-(float)getEstimateOfTotalVolumeInLiters{
    // if set, return last element of volume array
    return [self.constantSampledVolumeInLiters lastObject] ?
                ((NSNumber*)[self.constantSampledVolumeInLiters lastObject]).floatValue : 0;
}


@end
