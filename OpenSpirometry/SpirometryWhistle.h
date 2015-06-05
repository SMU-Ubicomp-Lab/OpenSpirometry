//
//  SpirometryWhistle.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>

struct WhistleDimensions { // in millimeters
    float Ddst;
    float Ldst;
    float Dcc;
    float Lcc;
    float Dit;
    float Lit;
};

@interface SpirometryWhistle : NSObject

@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) id tag; // for however the user wants to tag this whistle
@property (nonatomic) NSNumber *calibratedCoefficient; // the coefficient of proportionality
@property (nonatomic) NSNumber *calibratedBias; // bias term for regression

@property (nonatomic) NSNumber *calculatedCoefficient; // the coefficient of proportionality
@property (nonatomic) NSNumber *calculatedBias; // bias term for regression

@property (nonatomic) struct WhistleDimensions dimensions;

-(void)setAsWhistleWithDimensions:(struct WhistleDimensions)structDims;
-(void)setWhistleToDefault; // hard coded Sato, et al., Application of the Vortex Whistle to a Spirometer
-(BOOL)isCalibrated;
-(float)calcFlowInLiterPerSecondFromFrequencyInHz:(float)freq;

@end
