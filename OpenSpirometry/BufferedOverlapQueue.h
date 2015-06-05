//
//  BufferedOverlapQueue.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataBufferBlock.h"

typedef void (^ConsumeBlock)(); //TODO: only processing through delegation is currently supported

// delegation code manipulated from: http://stackoverflow.com/questions/626898/how-do-i-create-delegates-in-objective-c
@protocol DataBufferProcessDelegate <NSObject>
@optional
-(void)didFillBuffer:(DataBufferBlock*)block; // optional so that consume blocks can be used (BUT NOT BOTH!!)
-(void)didFinishProcessingAllBuffers;
@end

@interface BufferedOverlapQueue : NSObject

@property (nonatomic, weak) id <DataBufferProcessDelegate> delegate; // best way to process the data on demand in a separate concurrent queue

@property (nonatomic,readonly) NSUInteger numOverlapSamples;
@property (nonatomic,readonly) NSUInteger numSamplesPerBuffer;
@property (nonatomic,readonly) NSUInteger numFullBuffers;

-(id)initWithBufferLength:(NSUInteger)buffLength andOverlapLength:(NSUInteger)overlapLength;
-(void)addFreshFloatData:(float*)data withLength:(NSUInteger)numSamples;
-(void)addFreshInterleavedFloatData:(float*)data withLength:(NSUInteger)numSamples fromChannel:(NSUInteger)whichChannel withNumChannels:(NSUInteger)numChannels; // can only add one channel at a time
-(DataBufferBlock*)dequeueAndTakeOwnership; // TODO: you are responsible for freeing memory, more versatile
-(void)consumeBufferWithBlock:ConsumeBlock; // TODO: process buffer and free it, less versatile
-(void)deleteAt:(NSUInteger)indexToDelete;
-(void)clear;
-(void)processRemainingBlocks;

@end
