//
//  DataBufferBlock.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataBufferBlock : NSObject

@property (nonatomic) float *data;
@property (nonatomic,readonly) NSUInteger writePosition;
@property (nonatomic,readonly) NSUInteger length;
@property (nonatomic,readonly) CFTimeInterval timeCreated;
@property (nonatomic,readonly) BOOL isFull;

-(id)initWithCapacity:(NSUInteger)numItems;
-(void)addFloatData:(float*)data withLength:(NSUInteger)dataLength; // if this goes over length, only partial data copy
-(void)addInterleavedFloatData:(float*)data fromChannel:(NSUInteger)whichChannel withNumChannels:(NSUInteger)numChannels withLength:(NSUInteger)dataLength;

@end
