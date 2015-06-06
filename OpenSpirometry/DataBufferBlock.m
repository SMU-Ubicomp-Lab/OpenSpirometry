//
//  DataBufferBlock.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "DataBufferBlock.h"
#import<QuartzCore/QuartzCore.h>

@interface DataBufferBlock()

@property (nonatomic,readwrite) NSUInteger writePosition;
@property (nonatomic,readwrite) NSUInteger length;
@property (nonatomic,readwrite) CFTimeInterval timeCreated;
@property (nonatomic,readwrite) BOOL isFull;

@end

@implementation DataBufferBlock

-(float*)data{ // on demand in case never used
    if(!_data){
        _data = (float *)calloc(self.length,sizeof(float));
    }
    return _data;
}

-(id)initWithCapacity:(NSUInteger)numItems{
    if(self = [super init]){
        //set backing variables
        _length = numItems;
        _writePosition = 0;
        _timeCreated = CACurrentMediaTime();
        _isFull = NO;
        return self;
    }
    return nil;
}

-(id)init{
    return [self initWithCapacity:512]; //probably not what you want, use the designated init above
}

-(void)addFloatData:(float*)data withLength:(NSUInteger)dataLength{
    if(self.writePosition+dataLength <= self.length){ // wont go off the end, just copy
        memcpy(&self.data[self.writePosition], data, dataLength*sizeof(float));
        self.writePosition += dataLength;
    }else{ // we will go over the end, only copy some
        NSUInteger floatsToCopy = self.length - self.writePosition;
        memcpy(&self.data[self.writePosition], data, floatsToCopy*sizeof(float));
        self.writePosition += floatsToCopy;
    }
    
    if(self.writePosition >= self.length)
        self.isFull = YES;
}

-(void)addInterleavedFloatData:(float*)data fromChannel:(NSUInteger)whichChannel
               withNumChannels:(NSUInteger)numChannels withLength:(NSUInteger)dataLength
{
    if(self.writePosition+dataLength <= self.length){ // wont go off the end, just copy
        float *p = &data[whichChannel];
        for(int i=0;i<dataLength;++i,p+=numChannels){
            self.data[self.writePosition+i] = *p;
        }
        self.writePosition += dataLength;
    }else{ // we will go over the end, only copy some
        NSUInteger floatsToCopy = self.length - self.writePosition;
        float *p = &data[whichChannel];
        for(int i=0;i<floatsToCopy;++i,p+=numChannels){
            self.data[self.writePosition+i] = *p;
        }
        self.writePosition += floatsToCopy;
    }
    
    if(self.writePosition >= self.length)
        self.isFull = YES;
    
}


-(void)dealloc{
    if(_data){
        free(_data);
        _data = nil;
    }
}

@end
