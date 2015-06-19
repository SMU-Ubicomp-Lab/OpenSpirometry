//
//  FlowVolumeData.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlowVolumeDataAnalyzer : NSObject

@property (strong, nonatomic, readonly) NSNumber *peakFlowInLitersPerSecond;
@property (strong, nonatomic, readonly) NSNumber *fevOneInLiters;
@property (strong, nonatomic, readonly) NSNumber *fvcInLiters;
@property (strong, nonatomic, readonly) NSNumber *fevOneOverFvc; // computed property
@property (nonatomic,readonly) BOOL isFinalized;
@property (nonatomic, readonly) float preferredSamplingInterval; //TODO: write setter

-(void)addFlowEstimateInLitersPerSecond:(float)flow withTimeStamp:(CFAbsoluteTime)time;
-(float)getEstimateOfTotalVolumeInLiters;
-(NSDictionary*)finalizeCurvesAndGetResults;
-(void)addCustomErrorToEffort:(NSString*)errorMessage forKey:(NSString*)customKey; // errors are completely customizable
-(void)clearDataInEffort;

// how to get the data out in a good way? After finalizing:
//      measures are set from the curves,
//      maybe return the three NSArrays with time, volume, and flow rates
//      maybe they should all be placed in an NSDictionary that can be passed around

@end
