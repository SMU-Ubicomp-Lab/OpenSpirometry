//
//  SpirometerConstants.h
//  OpenSpirometry
//
//  Created by Eric Larson on 6/3/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#ifndef OpenSpirometry_SpirometerConstants_h
#define OpenSpirometry_SpirometerConstants_h

#define BUFFER_SIZE         44100
#define BUFFER_OVERLAP      BUFFER_SIZE-BUFFER_SIZE/200 // overlap, readings per second = Fs/BUFFER_SIZE * divisor
#define PEAK_WINDOW_SIZE    BUFFER_SIZE/1000 // num frequency bins to search over for local maxima
#define TIME_OUT_WAIT_FOR_TEST_START 10


// All these need calibration (SPIRO: needs calibration)
// TODO: find out are these need calibration for each whistle??
#define TEST_START_THRESH   1.5             // audio threshold to start test, should be greater than BUFFER_SIZE/Sampling rate
#define TEST_END_THRESH     1.01            // audio threshold to signal test is ending, not sure what this should be, maybe close to 1
#define PEAK_DBMAG_START      -2.5           // frequency magnitude for whistle peak (in dB)
#define PEAK_DBMAG_SUSTAINED  -20           // hysteresis magnitude once triggered
#define NUM_PEAKS_IS_COUGH  40               // hopefully whistle has a single fundamental
#define WAIT_DURATION_AFTER_PEAK 1          // time after large audio sound before saying the test is ending
#define WAIT_DURATION_AFTER_TEST 3          // in seconds, time after large audio to end the test
#define MIN_FREQUENCY_OF_WHISTLE_IN_HZ 60   // smallest detectable frquency we want
#define NUM_SAMPLES_BACK_FROM_PEAKFLOW_TO_INTERPOLATE 30 // number of samples to start the search for breaking monotnic values from the whistle



//define stages for our test
typedef enum : NSUInteger {
    SpirometryStageIsIdle,
    SpirometryStageIsCalibratingSilence,
    SpirometryStageIsWaitingForTestToBegin,
    SpirometryStageIsExhaling,
    SpirometryStageIsWaitingForEndOfTest,
    SpirometryStageIsFinished,
    SpirometryStageDidTimeOutWaitingForEffort,
    SpirometryStageIsAnalyzingResults,
} SpirometryStage;

#endif
