//
//  SpirometryWhistle.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//
// TODO: add support for other default whistles
//       need calibration coefficients for the others!!
// This class is the least built out and needs much more functionality for deployment

#import "SpirometryWhistle.h"

@implementation SpirometryWhistle

-(id)init{
    if(self=[super init]){
        [self setWhistleToDefault];
        return self;
    }
    return nil;
}

-(float)calcFlowInLiterPerSecondFromFrequencyInHz:(float)freq{
    if([self isCalibrated]){
        return freq*[self.calibratedCoefficient doubleValue] + [self.calibratedBias doubleValue];
    }
    else if(self.calculatedCoefficient!=nil && self.calculatedBias!=nil){
        return freq*[self.calculatedCoefficient doubleValue] + [self.calculatedBias doubleValue];
    }
    return -1.0; // no flow rate! TODO: maybe send error out that whistle is not calibrated
}

-(void)setWhistleToDefault{
    // Sato whistle dimensions
    self.name = @"Default Sato Whistle";
    self.tag = @"https://www.jstage.jst.go.jp/article/sicetr1965/35/7/35_7_840/_article";
    
    self.calibratedBias = @(2.42/89.5);
    self.calibratedCoefficient = @(1.0/89.5);
    
    self.calculatedBias = nil;
    self.calculatedBias = nil; // calced below, unneeded when
    
    _dimensions.Dcc = 35;
    _dimensions.Ddst = 26;
    _dimensions.Dit = 16;
    _dimensions.Lcc = 35;
    _dimensions.Ldst = 26;
    _dimensions.Lit = 40;
    
    [self calculateTermsFromDimensions];
    
}

-(void)setAsWhistleWithDimensions:(struct WhistleDimensions)structDims {
    self.dimensions = structDims;
    [self calculateTermsFromDimensions];
}

-(void)calculateTermsFromDimensions{
    self.calculatedBias = @0.01; // this probably can't be zero, settinf to Sato's values
    
    float R = 0.5*self.dimensions.Dcc;
    float A = M_PI*(self.dimensions.Dit/2.0)*(self.dimensions.Dit/2.0);
    float sinTheta = 0.65; // just a guess here to help match Sato's empirical study, the actual value needs calibration from generated vortices and density/temperature
    // is too difficult to count from the dimensions (value is between ~0.5 up to ~0.95, based on http://www.sciencedirect.com/science/article/pii/S0955598613000952# )
    float Rf = self.dimensions.Ddst/2.0; // approx from Ro
    float LpDeltaL = self.dimensions.Ldst+5.0; // addition here is also just a guess
    float mLPerHourToLitersPerSecond = 1.0/(1000.0*1000.0)/60.0;
    
    self.calculatedCoefficient = @(2.0*M_PI*R*A/sinTheta*sqrt(Rf*LpDeltaL) * mLPerHourToLitersPerSecond);
    
    // TODO: add in temperature stability when available: Sato & Watanabe, Experimental Study on the Use of a Vortex Whistle as a Flowmeter
}

-(BOOL) isCalibrated{
    return (self.calibratedCoefficient!=nil && self.calibratedBias!=nil);
}
@end
