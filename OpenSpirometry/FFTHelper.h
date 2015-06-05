//
//  FFTHelper.h
//  OpenSpirometry
//
//  Updated for objective-c implementation
//
//*  Real FFT wrapper for Apple's Accelerate Framework
//*
//*  Created by Parag K. Mital - http://pkmital.com
//*  Contact: parag@pkmital.com
//*
//*  Copyright 2011 Parag K. Mital. All rights reserved.
//  Modified by Eric Larson 2013.
//  Copyright (c) 2013 Eric Larson. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

enum WindowType {
    WindowTypeHann,
    WindowTypeHamming,
    WindowTypeRect,
    WindowTypeBlackman,
};

@interface FFTHelper : NSObject

@property (nonatomic,readonly) float *timeSeries; // for getting the invers FFT time series
@property (nonatomic,readonly) size_t fftSize;
@property (nonatomic,readonly) size_t fftSizeOver2;
@property (nonatomic,readonly) size_t windowSize;

- (id)init;
- (id)initWithFFTSize: (int)fftSize;
- (id)initWithFFTSize: (int)fftSize
            andWindow:(enum WindowType) winType;

-(void)performForwardFFTWithData:(float*)data;
-(void)copydBMagnitudeToBuffer:(float*)buffer;
-(void)performForwardFFTWithData:(float*)data andCopydBMagnitudeToBuffer:(float*)buffer;


//TODO: check inverse FFT and add to public API

@end
