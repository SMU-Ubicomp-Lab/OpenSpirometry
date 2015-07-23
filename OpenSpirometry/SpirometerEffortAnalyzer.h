//
//  SpirometerAnalyzer.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BufferedOverlapQueue.h"
#import "SpirometerConstants.h"
#import "SpirometryWhistle.h"

@protocol SpirometerEffortDelegate <NSObject>
@optional
-(void)didFinishCalibratingSilence;
-(void)didTimeoutWaitingForTestToStart;
-(void)didStartExhaling;
-(void)willEndTestSoon;
-(void)didCancelEffort;
-(void)didEndEffortWithResults:(NSDictionary*)results;
-(void)didUpdateFlow:(float)flowInLitersPerSecond andVolume:(float)volumeInLiters;
-(void)didUpdateAudioBufferWithMaximum:(float)maxAudioValue;
@end


@interface SpirometerEffortAnalyzer : NSObject <DataBufferProcessDelegate>

@property (nonatomic, weak) id <SpirometerEffortDelegate> delegate;
@property (nonatomic) SpirometryStage currentStage;
@property (strong, nonatomic) SpirometryWhistle* whistle;
@property (nonatomic) float prefferredAudioMaxUpdateIntervalInSeconds;


-(void)beginListeningForEffort;
-(void)askPermissionToUseAudioIfNotDone;
-(void)requestThatCurrentEffortShouldCancel;
-(void)requestThatEffortShouldEnd;
-(void)activateDebugAudioModeWithWAVFile:(NSString*)filenameAndPath;

//-(void)requestEndEffortInSeconds:(int)seconds;

@end
