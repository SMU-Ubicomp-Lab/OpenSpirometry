//
//  FlowVolumeData.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "FlowVolumeDataAnalyzer.h"
#import <Accelerate/Accelerate.h>

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
        
        _preferredSamplingInterval = 1.0/100.0;
        
        return self;
    }
    return nil;
}

#pragma mark Computed Properties

// all properties return @0 in error
-(NSNumber*)fevOneInLiters{
    // check to see if the arrays are built out enough to calculate this, then calculate it each time asked for
    for(int i=0;i<self.constantSampledCumulativeTime.count;i++){
        if([self.constantSampledCumulativeTime[i] floatValue]>1){
            return self.constantSampledVolumeInLiters[i];
        }
    }
    return @0;
}

-(NSNumber*)fvcInLiters{
    // only calculate if test is finalized
    return @([self getEstimateOfTotalVolumeInLiters]);
}

-(NSNumber*)peakFlowInLitersPerSecond{
    // check to see if the arrays are built out enough to calculate this, then calculate it each time asked for
    if(self.constantSampledFlowInLitersPerSecond.count>0){
        return [self.constantSampledFlowInLitersPerSecond valueForKeyPath:@"@max.self"];
    }
    return @0;
}

-(NSNumber*)fevOneOverFvc{
    NSNumber *val = @(self.fevOneInLiters.doubleValue/self.fvcInLiters.doubleValue);
    if([val isEqualToNumber:[NSDecimalNumber notANumber]] ){
        return @0;
    }
    return val;
}

#pragma mark Add/Clear Data Functions
-(void)addFlowEstimateInLitersPerSecond:(float)flow withTimeStamp:(CFAbsoluteTime)time{
    // Always assumign that data is arriving more slowly than our preferred sampling rate
    static float initialTime = 0;
    
    // add flow and time
    [self.dynamicSampledFlow addObject:@(flow)];
    [self.dynamicSampledTime addObject:@(time)];
    
    // interpolate flow and add points(s) to curve
    if(self.constantSampledCumulativeTime.count==0){
        initialTime = time;
        // setup the arrays
        [self.constantSampledCumulativeTime addObject:@(0)];
        [self.constantSampledFlowInLitersPerSecond addObject:@(flow)];
        [self.constantSampledVolumeInLiters addObject:@0]; // start with zero volume
    }
    else if(self.constantSampledCumulativeTime.count>=1){ // then we must linearly interpolate from last entry
        //TODO: it might be possible to back interpolate to zero flow here (using just the two values)
        //TODO: only run this on first two entries of flow and volume
        float timeX0 = [[self.constantSampledCumulativeTime lastObject] floatValue]; // already referenced to zero
        float timeX1 = time-initialTime; // make referenced to beginning of test
        float flowX0 = [[self.constantSampledFlowInLitersPerSecond lastObject] floatValue];
        float flowX1 = flow;
        
        float slope = (flowX1-flowX0) / (timeX1 - timeX0);
        
        // now let's fill in the data between x0 and x1
        float fillTime = timeX0 + self.preferredSamplingInterval;
        float newVolume = [[self.constantSampledVolumeInLiters lastObject] floatValue];
        
        while(fillTime <= timeX1){
            float newFlow = flowX0 + slope*(fillTime-timeX0); // calc interpolated flow
            newVolume += newFlow*self.preferredSamplingInterval; // add in volume (probably a really noisy estimate here, will smooth later)
            
            //add flow and new time
            [self.constantSampledFlowInLitersPerSecond addObject:@(newFlow)];
            [self.constantSampledVolumeInLiters addObject:@(newVolume)];
            [self.constantSampledCumulativeTime addObject:@(fillTime)];
            
            fillTime += self.preferredSamplingInterval;
        }
        
    }
    else // add if statement
    {
        // TODO: spline interpolations as num points is better for estimate
        
    }
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
    
    // TODO: check output and be sure this returns properly encapsulated, THIS IS NOT RETURNED YET
    // perform filtering of the flow rate
    NSMutableArray *filteredFlow = [self filterArray:self.constantSampledFlowInLitersPerSecond
                                       withFIRFilter:@[@0.00612500495896, @0.133331686187, @0.100128804544, @0.127394330804, @0.143746190497, @0.149443061676, @0.143746190497, @0.127394330804, @0.100128804544, @0.133331686187, @0.00612500495896]]; // lowpass filter created in python
// GENERATED VIA:----------------------------------------
//    from scipy.signal import fir_filter_design as fir
//    from scipy.signal import freqz
//    fir_taps = fir.remez(numtaps=11, bands=[0, 0.05, 0.1, 0.5],desired=[1,0])
//    w, h = freqz(fir_taps)
//-------------------------------------------------------
    
    
    //TODO: perform sharpness enhancement at the beginning of the test or try to use raw values to avoid biasing beginning of the test with filtering (important when use curve back propagation later on for detecting insufficient starts)
    
    //TODO: adjust time series samples to begin at zero with the start of the test
    //TODO: add in effort error checking (after the test)
    
    
    // Failures:{didCough, insufficient, early stop, bad start}
    // data: flowVolume, flowTime, volumeTime, common scalar measures
    
    // all blank for now, just so you get an idea of the structure of what is returned
    return @{@"FlowCurveInLitersPerSecond":[[NSArray alloc] initWithArray:self.constantSampledFlowInLitersPerSecond], // send back nonmutable copy
             @"VolumeCurveInLiters":[[NSArray alloc] initWithArray:self.constantSampledVolumeInLiters], // send back nonmutable copy
             @"TimeStampsForFlowAndVolume":[[NSArray alloc] initWithArray:self.constantSampledCumulativeTime], // send back nonmutable copy
             @"PeakFlowInLitersPerSecond":self.peakFlowInLitersPerSecond,
             @"FEVOneInLiters":self.fevOneInLiters,
             @"FVCInLiters":self.fvcInLiters,
             @"FEVOneOverFVC":self.fevOneOverFvc,
             @"ErrorsDictionary":[[NSDictionary alloc] initWithDictionary:self.errorsInEffort], // send back nonmutable copy
             };
    // this returned Dictionary should be very easy to save as JSON for developers and users
}

-(float)getEstimateOfTotalVolumeInLiters{
    // if set, return last element of volume array
    return [self.constantSampledVolumeInLiters lastObject] ?
                ((NSNumber*)[self.constantSampledVolumeInLiters lastObject]).floatValue : 0;
}


// maybe move this to a Util section
-(NSMutableArray*)filterArray:(NSArray*)series withFIRFilter:(NSArray*)coefficients{
    vDSP_Length lengthOfFilter = coefficients.count;
    vDSP_Length lengthOfResult = series.count+coefficients.count-1; // how does vDSP filter use "result" because it seems like this should just be the size of the input array to be filtered, but the name suggests differently. Look into this
    
    float *timeSeriesAsFloat = (float*)calloc(series.count,sizeof(float));
    float *filterAsFloat = (float*)calloc(coefficients.count,sizeof(float));
    float *outputAsFloat = (float*)calloc(series.count+coefficients.count-1,sizeof(float));
    float *pEndOfFilterAsFloat;
    
    // copy over as floats for processing
    for(int i=0;i<series.count;i++){
        timeSeriesAsFloat[i] = [[series objectAtIndex:i] floatValue];
    }
    
    for(int i=0;i<coefficients.count;i++){
        filterAsFloat[i] = [[coefficients objectAtIndex:i] floatValue];
    }
    
    pEndOfFilterAsFloat = &filterAsFloat[coefficients.count-1];
    
    //perform filtering
    vDSP_conv(timeSeriesAsFloat, 1, pEndOfFilterAsFloat, -1, outputAsFloat, 1, lengthOfResult, lengthOfFilter);
    
    // encapsulate the output and only copy over valid portions after processing
    NSMutableArray *outputEncapsulated = [[NSMutableArray alloc]initWithCapacity:series.count];
    for(int i=0;i<series.count;i++){
        outputEncapsulated[i] = @(outputAsFloat[i]);
    }
    
    free(timeSeriesAsFloat);
    free(outputAsFloat);
    free(filterAsFloat);
    
    return outputEncapsulated;
}


//// maybe move this to a Util section
//-(NSMutableArray*)filterArray:(NSArray*)series withIIRNumerator:(NSArray*)num andDenominator:(NSArray*)den{
//    vDSP_Length lengthOfFilter = coefficients.count;
//    vDSP_Length lengthOfResult = series.count+coefficients.count-1; // how does vDSP filter use "result" because it seems like this should just be the size of the input array to be filtered, but the name suggests differently. Look into this
//    
//    float *timeSeriesAsFloat = (float*)calloc(series.count,sizeof(float));
//    float *filterAsFloat = (float*)calloc(coefficients.count,sizeof(float));
//    float *outputAsFloat = (float*)calloc(series.count+coefficients.count-1,sizeof(float));
//    float *pEndOfFilterAsFloat;
//    
//    // copy over as floats for processing
//    for(int i=0;i<series.count;i++){
//        timeSeriesAsFloat[i] = [[series objectAtIndex:i] floatValue];
//    }
//    
//    for(int i=0;i<coefficients.count;i++){
//        filterAsFloat[i] = [[coefficients objectAtIndex:i] floatValue];
//    }
//    
//    pEndOfFilterAsFloat = &filterAsFloat[coefficients.count-1];
//    
//    //perform filtering
//    vDSP_conv(timeSeriesAsFloat, 1, pEndOfFilterAsFloat, -1, outputAsFloat, 1, lengthOfResult, lengthOfFilter);
//    vDSP_
//    
//    // encapsulate the output and only copy over valid portions after processing
//    NSMutableArray *outputEncapsulated = [[NSMutableArray alloc]initWithCapacity:series.count];
//    for(int i=0;i<series.count;i++){
//        outputEncapsulated[i] = @(outputAsFloat[i]);
//    }
//    
//    free(timeSeriesAsFloat);
//    free(outputAsFloat);
//    free(filterAsFloat);
//    
//    return outputEncapsulated;
//}


@end
