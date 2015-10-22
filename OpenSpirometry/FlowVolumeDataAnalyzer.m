//
//  FlowVolumeData.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "FlowVolumeDataAnalyzer.h"
#import "SpirometerConstants.h"
#import <Accelerate/Accelerate.h>
#import "CubicSpline.h"

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
    else if(self.constantSampledCumulativeTime.count==1){ // then we must linearly interpolate from last entry
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
    else if(self.dynamicSampledTime.count >= 3)
    {
        // do spline interpolations as num points is better for estimate
        NSUInteger lastElement = self.dynamicSampledTime.count;
        NSUInteger numSamplesToInterpolate = MIN(lastElement,5);
        
        // Use up to the last N elements for interpolation
        NSRange range = NSMakeRange(lastElement-numSamplesToInterpolate, numSamplesToInterpolate);
        NSMutableArray* timeX = [[self.dynamicSampledTime subarrayWithRange:range]mutableCopy];
        NSMutableArray* flowX = [[self.dynamicSampledFlow subarrayWithRange:range]mutableCopy];
        
        // zero index
        for(int i=0; i<timeX.count; i++){
            timeX[i] = @([timeX[i] doubleValue] - initialTime);
        }
        
        //create spline object
        CubicSpline* csp = [[CubicSpline alloc]initWithPointsX:timeX andY:flowX];
        float fillTime = [[self.constantSampledCumulativeTime lastObject] floatValue] + self.preferredSamplingInterval;
        float newVolume = [[self.constantSampledVolumeInLiters lastObject] floatValue];
        
        while(fillTime <= [[timeX lastObject] floatValue]){
            float newFlow = [csp interpolateX:fillTime]; // calc interpolated flow
            // if the interpolation is off, just adde the last flow rate
            if(newFlow <0)
                newFlow = [[self.constantSampledFlowInLitersPerSecond lastObject] floatValue];
            newVolume += newFlow*self.preferredSamplingInterval; // add in volume (probably a really noisy estimate here, will smooth later)
            
            //add flow and new time
            [self.constantSampledFlowInLitersPerSecond addObject:@(newFlow)];
            [self.constantSampledVolumeInLiters addObject:@(newVolume)];
            [self.constantSampledCumulativeTime addObject:@(fillTime)];
            
            fillTime += self.preferredSamplingInterval;
        }
        
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
                                       withFIRFilter:@[@(-0.0570114635), @(0.0477192582), @(0.0345309828), @(0.0268428757), @(0.0225935565), @(0.0203979552), @(0.0194419320), @(0.0192504413), @(0.0196427420), @(0.0203327997), @(0.0210234412), @(0.0219978553), @(0.0228894845), @(0.0237515661), @(0.0246741134), @(0.0254770231), @(0.0263172908), @(0.0270086622), @(0.0277167684), @(0.0282894016), @(0.0287857463), @(0.0291875253), @(0.0295200754), @(0.0297003562), @(0.0298753302), @(0.0298742843), @(0.0298753302), @(0.0297003562), @(0.0295200754), @(0.0291875253), @(0.0287857463), @(0.0282894016), @(0.0277167684), @(0.0270086622), @(0.0263172908), @(0.0254770231), @(0.0246741134), @(0.0237515661), @(0.0228894845), @(0.0219978553), @(0.0210234412), @(0.0203327997), @(0.0196427420), @(0.0192504413), @(0.0194419320), @(0.0203979552), @(0.0225935565), @(0.0268428757), @(0.0345309828), @(0.0477192582), @(-0.0570114635), ]]; // lowpass filter created in python
    
// GENERATED VIA:----------------------------------------
//    from scipy.signal import fir_filter_design as fir
//    from scipy.signal import freqz
//    fir_taps = fir.remez( SEE DOCUMENTATION FOR FILTER CREATION )
//-------------------------------------------------------
    
    
    //TODO: perform sharpness enhancement at the beginning of the test or try to use raw values to avoid biasing beginning of the test with filtering (important when use curve back propagation later on for detecting insufficient starts)
    filteredFlow = [self backExtrapolateFlowBeginningFromFlowArray:filteredFlow];
    
    //TODO: adjust time series samples to begin at zero with the start of the test
    //TODO: add in effort error checking (after the test)
    
    
    // Failures:{didCough, insufficient, early stop, bad start}
    // data: flowVolume, flowTime, volumeTime, common scalar measures
    
    //TODO: add metadata to dictionary for error checking during the analysis analysis
    
    //    if(DEBUG){
    //        NSLog(@"DynamicTime: %@\n\n Dynamic FLOW: %@",self.dynamicSampledTime, self.dynamicSampledFlow);
    //    }
    
    // all blank for now, just so you get an idea of the structure of what is returned
    return @{@"FlowCurveInLitersPerSecond":[[NSArray alloc] initWithArray:filteredFlow], // send back nonmutable copy
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

-(NSMutableArray*)backExtrapolateFlowBeginningFromFlowArray:(NSMutableArray*)flow{
    
    
    // need more checks here to backinterpolate
    float *flowAsFloat = (float*)calloc(flow.count,sizeof(float));
    for(int i=0;i<flow.count;i++){
        flowAsFloat[i] = [[flow objectAtIndex:i] floatValue];
    }
    
    // find peak flow and position
    float maxValue;
    vDSP_Length maxPosition;
    vDSP_maxvi(flowAsFloat, 1, &maxValue, &maxPosition, flow.count);
    
    vDSP_Length idxStartValidFlow = 5;
    // start at peak flow and find where we are not monotonic
    if(maxPosition>NUM_SAMPLES_BACK_FROM_PEAKFLOW_TO_INTERPOLATE)
        idxStartValidFlow = maxPosition - NUM_SAMPLES_BACK_FROM_PEAKFLOW_TO_INTERPOLATE;
        
    
    while(idxStartValidFlow > 5){
        if(flowAsFloat[idxStartValidFlow-1]<flowAsFloat[idxStartValidFlow])
            idxStartValidFlow--;
        else
            break;
    }
    
    // create range from the data and back interpolate
    NSRange range = NSMakeRange(idxStartValidFlow, maxPosition-idxStartValidFlow);
    NSMutableArray* timeX = [[self.constantSampledCumulativeTime subarrayWithRange:range]mutableCopy];
    NSMutableArray* flowX = [[flow subarrayWithRange:range]mutableCopy];
    CubicSpline* csp = [[CubicSpline alloc]
                        initWithPointsX:timeX
                                   andY:flowX];
    
    // now get the interpolated values if they are greater than zero (else just get them out of here!!!)
    int firstNonZeroElement = -1;
    for(int i=0;i<idxStartValidFlow;i++){
        float tmp = [csp interpolateX:[self.constantSampledCumulativeTime[i] floatValue]];
        if(tmp>=0 && tmp<flowAsFloat[i]){
            flowAsFloat[i] = tmp;
            if(firstNonZeroElement<0)
                firstNonZeroElement = i;
        }
        else if(tmp<0)
            flowAsFloat[i] = 0.0;
    }
    
    //    for(int i=(int)idxStartValidFlow;i<maxPosition;i++){
    //        float tmp = [csp interpolateX:[self.constantSampledCumulativeTime[i] floatValue]];
    //        if(tmp>=0)
    //            flowAsFloat[i] = (tmp+flowAsFloat[i])/2;
    //    }
    if(firstNonZeroElement>0){
        for(int i=0;i<self.constantSampledCumulativeTime.count;i++){
            self.constantSampledCumulativeTime[i] = @(self.preferredSamplingInterval*(i-firstNonZeroElement+1));
        }
    }
    
    // now re-encapsulate it and move on
    for(int i=0;i<flow.count;i++){
        flow[i] = @(flowAsFloat[i]);
    }
    
    free(flowAsFloat);
    
    return flow;
}


@end
