//
//  SpirometerAnalyzer.m
//  OpenSpirometry
//
//  Created by Eric Larson
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// TODO: save flow rate
// TODO: calculate volume from analyzer (separate model)
// TODO: provide end of effort analytics (separate model): cough, bad start, not long enough, insufficient effort
// TODO: enable custom whistles through some mechanism for setting the whistle (use UI Delegate for presenting settings)
// TODO: whistle frequency converter (should be stored in this model, most likely)
// TODO: extrapolate tail (don't want this--can the whistle be made better to get the lower range? How Low?)
// TODO: fundamental peak following across frames
// TODO: provide reproducibility analytics (in separate model, not built yet)

#import "SpirometerEffortAnalyzer.h"
#import <QuartzCore/QuartzCore.h>
#import "Novocaine.h"
#import "FFTHelper.h"
#import "BufferedOverlapQueue.h"
#import "PeakFinder.h"
#import "FlowVolumeDataAnalyzer.h"

@interface SpirometerEffortAnalyzer()

@property (strong, nonatomic) Novocaine* audioManager;
@property (strong, nonatomic) FFTHelper* fftHelper;
@property (strong, nonatomic) BufferedOverlapQueue* dataBuffer;
@property (strong, nonatomic) PeakFinder *peakFinder;
@property (strong, nonatomic) FlowVolumeDataAnalyzer *fvAnalyzer;

@property (atomic) BOOL isShuttingDown;
@property (nonatomic) NSUInteger samplesRead;
@property (atomic) NSUInteger numBlocksProcessed;
@property (atomic) NSUInteger numProcessedSamples;
@property (nonatomic) float frequencyResolution;
@property (nonatomic) float silenceThreshold;
@property (nonatomic) BOOL silenceThresholdIsSet;

@end


@implementation SpirometerEffortAnalyzer{
    struct {
        unsigned int didFinishCalibratingSilence:1;
        unsigned int didTimeoutWaitingForTestToStart:1;
        unsigned int didStartExhaling:1;
        unsigned int willEndTestSoon:1;
        unsigned int didCancelEffort:1;
        unsigned int didEndEffortWithResults:1;
        unsigned int didUpdateFlowAndVolume:1;
        unsigned int didUpdateAudioBufferWithMaximum:1;
    } delegateRespondsTo;
}

- (void)setDelegate:(id <SpirometerEffortDelegate>)aDelegate {
    if (_delegate != aDelegate) {
        _delegate = aDelegate;
        delegateRespondsTo.didFinishCalibratingSilence = [_delegate respondsToSelector:@selector(didFinishCalibratingSilence)];
        delegateRespondsTo.didTimeoutWaitingForTestToStart = [_delegate respondsToSelector:@selector(didTimeoutWaitingForTestToStart)];
        delegateRespondsTo.didStartExhaling = [_delegate respondsToSelector:@selector(didStartExhaling)];
        delegateRespondsTo.willEndTestSoon = [_delegate respondsToSelector:@selector(willEndTestSoon)];
        delegateRespondsTo.didCancelEffort = [_delegate respondsToSelector:@selector(didCancelEffort)];
        delegateRespondsTo.didEndEffortWithResults = [_delegate respondsToSelector:@selector(didEndEffortWithResults:)];
        delegateRespondsTo.didUpdateFlowAndVolume = [_delegate respondsToSelector:@selector(didUpdateFlow:andVolume:)];
        delegateRespondsTo.didUpdateAudioBufferWithMaximum = [_delegate respondsToSelector:@selector(didUpdateAudioBufferWithMaximum:)];
    }
}


#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
        
        // and the other properties dependent here
        _frequencyResolution = ((float)BUFFER_SIZE)/_audioManager.samplingRate;
        _peakFinder = [[PeakFinder alloc]initWithFrequencyResolution:_frequencyResolution];
    }
    return _audioManager;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc] initWithFFTSize:BUFFER_SIZE
                                              andWindow:WindowTypeHann];
    }
    return _fftHelper;
}

#pragma mark Init/Dealloc
// set up as singleton class
+ (SpirometerEffortAnalyzer *) spirometerAnalyzer
{
    static SpirometerEffortAnalyzer * _sharedInstance = nil;
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate,^{
        _sharedInstance = [[SpirometerEffortAnalyzer alloc] init];
    });
    
    return _sharedInstance;
}

-(id)init{
    
    if(self = [super init]){
        [self setup];
        return self;
    }
    return nil;
}

-(void)dealloc{
    if(_audioManager){
        [_audioManager setInputBlock:nil];
        [_audioManager teardownAudio];
    }
}

-(void) safeFree:(float **) var{
    // don't want to use c++ here for passing by reference so instead we will use double indirection
    if(*var){
        free(*var);
    }
    *var = nil;
}

-(void) setup{
    
    // instantiate in init
    _dataBuffer = [[BufferedOverlapQueue alloc] initWithBufferLength:BUFFER_SIZE andOverlapLength:BUFFER_OVERLAP];
    _dataBuffer.delegate = self;
    
    _isShuttingDown = NO;
    _samplesRead = 0;
    _numBlocksProcessed = 0;
    _numProcessedSamples = 0;
    _silenceThreshold = 0;
    _silenceThresholdIsSet = NO;
    _currentStage = SpirometryStageIsIdle;
    _prefferredAudioMaxUpdateIntervalInSeconds = 1.0/30.0; // 30FPS default
    
    _whistle = [[SpirometryWhistle alloc]init]; // whistle is set to default params (Sato Whistle)
    
    _fvAnalyzer = [[FlowVolumeDataAnalyzer alloc] init];
    
}

#pragma mark Permission
// return if successful
-(void)askPermissionToUseAudioIfNotDone{
    if(![self delegateCanPresentUI]){return;}
    
    if(self.currentStage == SpirometryStageIsIdle){
        //display alert if permissions not set
        //      maybe get text for alert from use or provide default
        
        enum AVAudioSessionRecordPermission auth = [Novocaine checkAudioAuthorization];

        //BOOL shouldInformUserDeviceIsRestricted = NO; // No support for this yet in AVAudioSession
        switch (auth) {
            case AVAudioSessionRecordPermissionGranted:
            {
                // nothing to do, audio can be setup now without prompting
                [self setupAudio];
            }
                break;
            case AVAudioSessionRecordPermissionDenied:
            {
                //we have been denied in the past
                [self informUserToChangeRecordingSettings];
            }
                break;
            case AVAudioSessionRecordPermissionUndetermined:
                // ask for access twice, once where we explain the process, then with iOS
                [self explainRecordingPermissions];
                break;
            //case Restricted: // No support for this yet in AVAudioSession yet
                //shouldInformUserDeviceIsRestricted = YES;
        }
    }
}

-(BOOL)delegateCanPresentUI{
    if(!self.delegate){return NO;} // if no delegate, no UI. sorry
    if(![self.delegate isKindOfClass:[UIViewController class]]){return NO;} // not a UIcontroller, can't do this, sorry
    return YES;
}

-(void)informUserToChangeRecordingSettings{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Microphone Access Denied Previously"
                                                                   message:@"To perform a spirometry test, you will need to allow this app access to record audio.\n\n To allow access: \n1. Close this app. \n2.Open settings from the home screen.\n3. Find and Click on this app. \n4. Change the privacy to \"Allow\". "
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                          }];
    //TODO: add a "settings" button for easy launch
    
    [alert addAction:defaultAction];
    [(UIViewController*)self.delegate presentViewController:alert animated:YES completion:nil];
}

-(void)explainRecordingPermissions{
    if([self delegateCanPresentUI]){
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Need Microphone Access"
                                                                       message:@"To perform a spirometry test, you will need to allow this app recording access in order to listen to the sound of the test. \n\nRecording will only occur during the test and will never be saved."
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Allow" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  NSLog(@"User wants to attain access.");
                                                                  [self setupAudio];
                                                              }];
        
        UIAlertAction* refuseAction = [UIAlertAction actionWithTitle:@"Ask Later" style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * action) {
                                                                 NSLog(@"User will wait to allow access");
                                                             }];
        
        [alert addAction:defaultAction];
        [alert addAction:refuseAction];
        [(UIViewController*)self.delegate presentViewController:alert animated:YES completion:nil];
    }
}

-(void)askForRecordingPermission{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            NSLog(@"Recording Permission Granted through Prompt");
            [self setupAudio];
        } else {
            NSLog(@"Recording Permission Denied through Prompt");
        }
    }];
}

#pragma mark Analyze Audio Methods

-(void)setupAudio{
    [self.audioManager setInputBlock:nil];
    [self.audioManager pause];
    
    self.currentStage = SpirometryStageIsIdle;
    
}

-(void)resetEffort{
    self.samplesRead = 0;
    self.numBlocksProcessed = 0;
    self.numProcessedSamples = 0;
    self.silenceThreshold = 0;
    self.silenceThresholdIsSet = NO;
    self.isShuttingDown = NO;
    
    [self.fvAnalyzer clearDataInEffort]; // object recycled for each effort
}


-(void)beginListeningForEffort{
    [self resetEffort];
    
    self.currentStage = SpirometryStageIsCalibratingSilence;
    
    // audio instantiated here if neccessary (will generate microphone ask if not set)
    // grab non-reference count adding handle to ourselves
    __block __weak typeof(self) weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         // add data to the ring buffer (interleaved in case iOS upgrades microphone or test is over airplay)
         if(weakSelf && !weakSelf.isShuttingDown){
             
             // copy data over to overlap buffer
             [weakSelf.dataBuffer addFreshInterleavedFloatData:data withLength:numFrames fromChannel:0 withNumChannels:numChannels];
             
             weakSelf.samplesRead += numFrames; // increment the total samples collected thus far
             
             
             // get max of this buffer stream
             float maxValue;
             vDSP_maxv(data, 1, &maxValue, numFrames);
             
             // now get out of this block! It needs to run way too often
             dispatch_async(dispatch_get_main_queue(),^{
                 // analyze stage based on most recent data (super fast for small frame size here)
                 weakSelf.currentStage = [weakSelf analyzeStagesFromAudioMax:maxValue];
                 
                 // shut down audio from main queue if needed
                 // this has sync code in it, so it might be a bit slow for the main queue
                 [weakSelf endEffortIfDone];
             });
         }
     }];
    
    [self.audioManager play];
}


-(SpirometryStage)analyzeStagesFromAudioMax:(float)maxValue{
    
    static BOOL testStarted = NO;
    static CFTimeInterval lastGoodTime = 0;
    static CFTimeInterval testStartTime = 0;
    static CFTimeInterval silencedEndedStartTime = 0;
    
    if( self.samplesRead < BUFFER_SIZE*2){
        // still collecting samples for silence
        //reset state
        testStarted = NO;
        lastGoodTime = 0;
        testStartTime = 0;
        silencedEndedStartTime = 0;
        
        // better be quite here
        self.silenceThreshold = maxValue>self.silenceThreshold ? maxValue : self.silenceThreshold;
        return SpirometryStageIsCalibratingSilence;
    }
    else if(!self.silenceThresholdIsSet && self.samplesRead >= BUFFER_SIZE*2){
        // just finished getting all the samples here, lock in silence threshold and notify delegate
        self.silenceThresholdIsSet = YES; // now we are set
        silencedEndedStartTime = CACurrentMediaTime();
        
        if(delegateRespondsTo.didFinishCalibratingSilence){
            dispatch_async(dispatch_get_main_queue(),^{
                //delegation on main queue for did finish calibrating
                [self.delegate didFinishCalibratingSilence];
            });
        }
    }
    
    // update the delegate about the audio (this will happen after calibrating silence)
    if(delegateRespondsTo.didUpdateAudioBufferWithMaximum){
        static CFTimeInterval lastAudioUpdateTime = 0;
        CFTimeInterval tempCurrTime = CACurrentMediaTime();
        CFTimeInterval elapsedTimeForAudioUpdate = tempCurrTime-lastAudioUpdateTime;
        if(lastAudioUpdateTime==0 || elapsedTimeForAudioUpdate >= self.prefferredAudioMaxUpdateIntervalInSeconds){
            lastAudioUpdateTime = tempCurrTime;
            dispatch_async(dispatch_get_main_queue(),^{
                //delegation on main queue for did finish calibrating
                [self.delegate didUpdateAudioBufferWithMaximum:maxValue];
            });
        }
    }
    
    if(testStarted){
        
        CFTimeInterval elapsedTime = CACurrentMediaTime()-lastGoodTime;
        if(maxValue>TEST_END_THRESH*self.silenceThreshold){
            // audio still way above threshold
            lastGoodTime = CACurrentMediaTime();
            return SpirometryStageIsExhaling;
        }
        else {
            if(elapsedTime>WAIT_DURATION_AFTER_TEST){ // has low audio for a while now, end effort
                NSLog(@"Test has finished (no more audible sound)");
                return SpirometryStageIsFinished;
            }else if(elapsedTime<WAIT_DURATION_AFTER_PEAK){
                // below, threshold, but too close to last update to end the audio test
                return SpirometryStageIsExhaling;
            }
            if(delegateRespondsTo.willEndTestSoon){
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.delegate willEndTestSoon];
                });
            }
            return SpirometryStageIsWaitingForEndOfTest;
        }
        return SpirometryStageIsExhaling;
    }
    else if(maxValue>TEST_START_THRESH*self.silenceThreshold){
        testStarted = YES;
        lastGoodTime = CACurrentMediaTime();
        testStartTime = lastGoodTime-1.0;
        NSLog(@"Spirometry Effort has begun");
        
        if(delegateRespondsTo.didStartExhaling){
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate didStartExhaling];
            });
        }
        
        return SpirometryStageIsExhaling;
    }
    
    CFTimeInterval effortWaitTime =CACurrentMediaTime()-silencedEndedStartTime;

    if(silencedEndedStartTime!=0 && effortWaitTime > TIME_OUT_WAIT_FOR_TEST_START){
        return SpirometryStageDidTimeOutWaitingForEffort;
    }
    
    return SpirometryStageIsWaitingForTestToBegin;
}

// this delegate method is performed asynchronously
// if blocks are not consumed faster than they are added, then memory will build up
// the block passed in is freed immediately after this executes
-(void)didFillBuffer:(DataBufferBlock *)block{
    
    //CFAbsoluteTime timeInQueue = CACurrentMediaTime()-block.timeCreated;
    
    const unsigned long lenMagBuffer = self.fftHelper.fftSizeOver2;
    float *fftMagnitudeBuffer = (float *)calloc(lenMagBuffer,sizeof(float));
    
    // take FFT
    [self.fftHelper performForwardFFTWithData:block.data
                     andCopydBMagnitudeToBuffer:fftMagnitudeBuffer];
    
    
    // find local maxima and identify most likely harmonics of whistle (returns nil if none exist)
    NSArray *fundamentalFrequencies = [self.peakFinder getFundamentalPeaksFromBuffer:fftMagnitudeBuffer
                                                                          withLength:lenMagBuffer
                                                                     usingWindowSize:PEAK_WINDOW_SIZE
                                                             andPeakMagnitudeMinimum:PEAK_DBMAG_MIN
                                                                      aboveFrequency:MIN_FREQUENCY_OF_WHISTLE_IN_HZ];
    
    // if there was at least one fundamental peak frequency
    if(fundamentalFrequencies){
        if([fundamentalFrequencies count] > NUM_PEAKS_IS_COUGH){ // identify spectra with many peaks as cough
            NSLog(@"Detected cough from %ld peaks", (unsigned long)[fundamentalFrequencies count]);
            [self.fvAnalyzer addCustomErrorToEffort:@"Cough Detected During Test"
                                             forKey:@"Cough"];
        }
        
        // first pass flow rate detection (no fundamental following yet)
        float frequency = ((Peak*)[fundamentalFrequencies objectAtIndex:0]).frequency;
        
        // convert to flow rate from frequency using whistle model
        float flow = [self.whistle calcFlowInLiterPerSecondFromFrequencyInHz:frequency];
        float volume;
        
        [self.fvAnalyzer addFlowEstimateInLitersPerSecond:flow // calced flow rate
                                            withTimeStamp:block.timeCreated]; // original time stamp for audio
        
        // query running volume from analyzer (using the new flow we just passed in)
        volume = [self.fvAnalyzer getEstimateOfTotalVolumeInLiters]; // TODO: model currently just returns zero, will be built out later
        
        // call delegate did update flow and volume on main queue
        if(delegateRespondsTo.didUpdateFlowAndVolume){
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate didUpdateFlow:flow andVolume:volume];
            });
        }

    }
    else{
        //TODO: handle frequency dropout
    }
    
//    if(DEBUG)
//    {
//        // find maximum of spectrum, just some debug info here
//        float maxValue;
//        unsigned long maxIndex;
//        vDSP_maxvi(fftMagnitudeBuffer, 1, &maxValue, &maxIndex, lenMagBuffer);
//        
//        float interpolatedFrequency = [self.peakFinder getFrequencyFromIndex:maxIndex usingData:fftMagnitudeBuffer];
//        NSLog(@"Freq = %.2f, Mag=%.2f, QTime = %.2f, Blocks = %ld",
//              interpolatedFrequency,
//              maxValue,
//              timeInQueue,
//              (unsigned long)self.dataBuffer.numFullBuffers);
//    }
    
    free(fftMagnitudeBuffer);
}

-(void)didFinishProcessingAllBuffers{
    // if number of buffers is all done, and we are shutting down
    if(self.isShuttingDown && self.currentStage==SpirometryStageIsFinished){
        
        self.currentStage = SpirometryStageIsAnalyzingResults;
        
        // finalize and get the results
        NSDictionary *results = [self.fvAnalyzer finalizeCurvesAndGetResults];
        
        // perform delegation for effort did finish
        if(delegateRespondsTo.didEndEffortWithResults){
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate didEndEffortWithResults:[[NSDictionary alloc]initWithDictionary:results]];
            });
        }
        
        // add this for synchronization of the serial main queue (not UI related, but simple calculation so, meh)
        dispatch_async(dispatch_get_main_queue(),^{
            self.currentStage = SpirometryStageIsIdle;
        });
    }
}


-(void)endEffortIfDone{ // only called from main queue
    if(!self.isShuttingDown){
        if(self.currentStage == SpirometryStageIsFinished)
        {
            self.isShuttingDown = YES; // this function should only be called from main queue so no semaphore needed
            NSLog(@"Effort did end, Shutting Down Audio");
            [self.audioManager pause]; // stop
            [self.dataBuffer processRemainingBlocks]; // kill remainder of queue
            
        }
        else if(self.currentStage == SpirometryStageDidTimeOutWaitingForEffort){
            self.isShuttingDown = YES; // this function should only be called from main queue so no semaphore needed
            NSLog(@"Effort did time out waiting");
            [self.audioManager pause]; // stop
            [self.dataBuffer clear];
            
            self.currentStage = SpirometryStageIsIdle;
            
            // perform delegation for effort did timeout
            if(delegateRespondsTo.didTimeoutWaitingForTestToStart){
                [self.delegate didTimeoutWaitingForTestToStart];
            }
        }
    }
}


#pragma mark User Request Controls
-(void)requestThatCurrentEffortShouldCancel{
    if(self.currentStage != SpirometryStageIsIdle){
        dispatch_async(dispatch_get_main_queue(),^{
            self.isShuttingDown = YES; // this function should only be called from main queue so no semaphore needed
            NSLog(@"Effort cancelled");
            [self.audioManager pause]; // stop
            [self.dataBuffer clear];
            
            self.currentStage = SpirometryStageIsIdle;
            
            // perform delegation for effort was cancelled successfully
            if(delegateRespondsTo.didCancelEffort){
                [self.delegate didCancelEffort];
            }
        });
    }
}

-(void)requestThatEffortShouldEnd{
    // add this for synchronization of the serial main queue (not UI related, but simple calculation so, meh)
    dispatch_async(dispatch_get_main_queue(),^{
        NSLog(@"Requesting that effort should end, user inititated");
        self.currentStage = SpirometryStageIsFinished;
        [self endEffortIfDone];
    });
}



@end
