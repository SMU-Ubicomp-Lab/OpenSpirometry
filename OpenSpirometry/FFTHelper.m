//
//  FFTHelper.m
//  OpenSpirometry
//
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


#import "FFTHelper.h"

@interface FFTHelper()

@property (nonatomic, readwrite) size_t fftSize;
@property (nonatomic, readwrite) size_t fftSizeOver2;
@property (nonatomic, readwrite) size_t windowSize;
@property (nonatomic) size_t log2n;
@property (nonatomic) size_t log2nOver2;

@property (nonatomic) float *in_real;
@property (nonatomic) float *out_real;
@property (nonatomic) float *window;
@property (nonatomic, readwrite) float *magnitude;
@property (nonatomic, readwrite) float *timeSeries;
@property (nonatomic) BOOL needsMagnitude;

@property (nonatomic) float scale;

@property (nonatomic) FFTSetup fftSetup;
@property (nonatomic) COMPLEX_SPLIT split_data;

@property (nonatomic) enum WindowType winType;

@end

@implementation FFTHelper

#pragma mark Lazy Instantiation
-(float *)in_real{
    if(!_in_real){
        _in_real = (float *) malloc(self.fftSize * sizeof(float));
    }
    return _in_real;
}

-(float *)out_real{
    if(!_out_real){
        _out_real = (float *) malloc(self.fftSize * sizeof(float));
    }
    return _out_real;
}

-(float *)magnitude{
    if(!_magnitude){
        _magnitude = (float *) malloc(self.fftSizeOver2 * sizeof(float));
    }
    return _magnitude;
}

-(void)copydBMagnitudeToBuffer:(float*)buffer{
    
    if(self.needsMagnitude){
        self.needsMagnitude = NO; // not exactly a mutex, but meh...
        // auto calculate the magnitude (TODO: calc phase if needed on demand)
        vDSP_zvmags(&_split_data, 1, self.magnitude, 1, self.fftSizeOver2);
        float scale = 1.0f/sqrtf(self.scale); // force spectrogram type scaling
        vDSP_vdbcon (self.magnitude, 1, &scale, self.magnitude, 1, self.fftSizeOver2, 0);
    }
    memcpy(buffer, self.magnitude, self.fftSizeOver2*sizeof(float));
}

-(float *)timeSeries{
    if(!_timeSeries){
        _timeSeries = (float *) malloc(self.fftSize * sizeof(float));
    }
    return _timeSeries;
}



#pragma mark Init and Setup
- (id)init
{
    return [self initWithFFTSize:4096 andWindow:WindowTypeHann];
}

- (id)initWithFFTSize: (int)fftSize
{
    return [self initWithFFTSize:fftSize andWindow:WindowTypeHann];
}

- (id)initWithFFTSize: (int)fftSize
            andWindow:(enum WindowType) winType
{
    if (self = [super init])
    {
        _fftSize = fftSize;
        _winType = winType;
        _windowSize = fftSize;
        
        [self setup];
        return self;
    }
    return nil;
}

-(void)setup{
    //Default:int size = 4096, int window_size = 4096, WindowType winType = WindowTypeHann
    
    self.fftSizeOver2 = self.fftSize/2;
    self.log2n = log2f(self.fftSize);
    self.log2nOver2 = self.log2n/2;
    
    self.needsMagnitude = YES;
    
    _split_data.realp = (float *) malloc(self.fftSizeOver2 * sizeof(float));
    _split_data.imagp = (float *) malloc(self.fftSizeOver2 * sizeof(float));
    
    
    if(self.winType != WindowTypeRect){
        self.window = (float *) malloc(sizeof(float) * self.windowSize);
        memset(self.window, 0, sizeof(float) * self.windowSize);
        switch (self.winType) {
            case WindowTypeHann:
                vDSP_hann_window(self.window, self.windowSize, vDSP_HANN_DENORM);
                break;
            case WindowTypeHamming:
                vDSP_hamm_window(self.window, self.windowSize, vDSP_HANN_DENORM);
                break;
            case WindowTypeBlackman:
                vDSP_blkman_window(self.window, self.windowSize, vDSP_HANN_DENORM);
                break;
            default:
                vDSP_hann_window(self.window, self.windowSize, vDSP_HANN_DENORM);
                break;
        }
        
    }
    else{
        self.windowSize = 0;
        self.window = nil;
    }
    
    self.scale = 1.0f/(float)(4.0f*self.fftSize);
    
    // allocate the fft object once
    self.fftSetup = vDSP_create_fftsetup(self.log2n, FFT_RADIX2);
    if (self.fftSetup == NULL) {
        printf("\nFFT_Setup failed to allocate enough memory.\n");
    }
    
}

-(void)dealloc{
    
    // free memory (the function uses double indirection for similar functionality to "pass by reference")
    [self safeFree:&_in_real];
    [self safeFree:&_out_real];
    [self safeFree:&_magnitude];
    [self safeFree:&(_split_data.realp)];
    [self safeFree:&(_split_data.imagp)];
    
    vDSP_destroy_fftsetup(_fftSetup);
}

-(void) safeFree:(float **) var{
    // don't want to use c++ here for passing by reference so instead we will use double indirection
    if(*var){
        free(*var);
    }
    //*var = nil;
}

#pragma mark Perform FFT and IFFT
-(void)performForwardFFTWithData:(float*)buffer{
    
    //multiply by window
    if( self.window != NULL )
        vDSP_vmul(buffer, 1, self.window, 1, self.in_real, 1, self.fftSize);
    else
        memcpy(self.in_real,buffer,self.fftSize);
    
    //convert to split complex format with evens in real and odds in imag
    vDSP_ctoz((COMPLEX *) self.in_real, 2, &_split_data, 1, self.fftSizeOver2);
    
    //calc fft
    vDSP_fft_zrip(self.fftSetup, &_split_data, 1, self.log2n, FFT_FORWARD);
    
    _split_data.imagp[0] = 0.0;
    
    self.needsMagnitude = YES;
    
//    for (int i = 0; i < self.fftSizeOver2; i++)
//    {
//        //compute power
//        float power = _split_data.realp[i]*_split_data.realp[i] +
//        _split_data.imagp[i]*_split_data.imagp[i];
//        
//        //compute  phase
//        phase[i] = atan2f(_split_data.imagp[i], _split_data.realp[i]);
//    }
}

-(void)performForwardFFTWithData:(float*)data andCopydBMagnitudeToBuffer:(float*)buffer{
    // 90% of what this class does is for magnitude so making a convenience method
    [self performForwardFFTWithData:data];
    [self copydBMagnitudeToBuffer:buffer];
}

-(void)performInverseFFTWithMagnitude:(float *)magnitude
                             andPhase:(float*)phase{
    
    float *real_p = _split_data.realp;
    float *imag_p = _split_data.imagp;
    
    for (int i = 0; i < self.fftSizeOver2; i++) {
        *real_p++ = magnitude[i] * cosf(phase[i]);
        *imag_p++ = magnitude[i] * sinf(phase[i]);
    }
    
    vDSP_fft_zrip(self.fftSetup, &_split_data, 1, self.log2n, FFT_INVERSE);
    vDSP_ztoc(&_split_data, 1, (COMPLEX*) self.out_real, 2, self.fftSizeOver2);
    
    vDSP_vsmul(self.out_real, 1, &_scale, self.out_real, 1, self.fftSize);
    
    // multiply by window w/ overlap-add
    
    float *p = _timeSeries; // allocated here if not set
    for (int i = 0; i < self.fftSize; i++) {
        *p++ += _out_real[i] * _window[i];
    }
    
    
}




@end




























