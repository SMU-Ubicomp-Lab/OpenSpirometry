//
//  BufferedOverlapQueue.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import "BufferedOverlapQueue.h"


@interface BufferedOverlapQueue()

@property (strong, atomic) NSMutableArray* overlapQueue;
@property (atomic) NSUInteger currentFillQueueIndex;

@property (nonatomic,readwrite) NSUInteger numOverlapSamples;
@property (nonatomic,readwrite) NSUInteger numSamplesPerBuffer;
@property (nonatomic,readwrite) NSUInteger numFullBuffers;

@end

@implementation BufferedOverlapQueue {
    struct {
        unsigned int didFillBuffer:1;
        unsigned int didFinishProcessingAllBuffers:1;
    } delegateRespondsTo;
}

- (void)setDelegate:(id <DataBufferProcessDelegate>)aDelegate {
    if (_delegate != aDelegate) {
        _delegate = aDelegate;
        delegateRespondsTo.didFillBuffer = [_delegate respondsToSelector:@selector(didFillBuffer:)];
        delegateRespondsTo.didFinishProcessingAllBuffers = [_delegate respondsToSelector:@selector(didFinishProcessingAllBuffers)];
    }
}

-(id)initWithBufferLength:(NSUInteger)buffLength andOverlapLength:(NSUInteger)overlapLength{
    if(self = [super init]){
        _numFullBuffers = 0;
        _currentFillQueueIndex = 0;
        _numSamplesPerBuffer = buffLength;
        _numOverlapSamples = overlapLength;
        _overlapQueue = [[NSMutableArray alloc]init];
        // init the first member of the queue
        [_overlapQueue addObject:[[DataBufferBlock alloc]initWithCapacity:_numSamplesPerBuffer]];
        return self;
    }
    return nil;
}

-(id) init{
    // probably not what you want. Use the designated init above
    return [self initWithBufferLength:512 andOverlapLength:256];
}

-(void)addFreshFloatData:(float*)data withLength:(NSUInteger)numSamples{
    [self addFreshInterleavedFloatData:data withLength:numSamples
                           fromChannel:0 withNumChannels:1];
}


-(void)addFreshInterleavedFloatData:(float*)data withLength:(NSUInteger)numSamples fromChannel:(NSUInteger)whichChannel withNumChannels:(NSUInteger)numChannels{
    // copy data in a hurry, this block likely occurs in a streaming process
    NSUInteger increment = self.numSamplesPerBuffer - self.numOverlapSamples;
    NSUInteger dataCopyLength = numSamples;
    
    NSUInteger idx = 0;
    
    @synchronized(self){
        
        if(numSamples > self.numSamplesPerBuffer){
            // this only works for input data greater than BufferSize
            for(int i=0; i<numSamples; i+=increment, idx++, dataCopyLength-=increment){
                if(self.currentFillQueueIndex+idx >= [self.overlapQueue count]){ // add object if we need it
                    [self.overlapQueue addObject:[[DataBufferBlock alloc]initWithCapacity:self.numSamplesPerBuffer]];
                }
                [self addData:&data[i] withSize:dataCopyLength fromChannel:whichChannel withNumChannels:numChannels
                toBufferBlock:self.overlapQueue[self.currentFillQueueIndex+idx]];
            }
        }else{
            
            // this only works for input data fewer than BufferSize
            DataBufferBlock* block = [self.overlapQueue lastObject];
            if(block.writePosition+numSamples>increment){ // need new entry
                [self.overlapQueue addObject:[[DataBufferBlock alloc]initWithCapacity:self.numSamplesPerBuffer]];
            }
            
            // add given data to each block
            for(DataBufferBlock* block in self.overlapQueue){
                if(!block.isFull){
                    [self addData:data withSize:numSamples fromChannel:whichChannel withNumChannels:numChannels
                    toBufferBlock:block];
                }
            }
        }
        
        // Update write position
        idx = 0;
        for(DataBufferBlock* block in self.overlapQueue){
            if(block.isFull){
                idx++;
            }
        }
        self.currentFillQueueIndex = idx;
        self.numFullBuffers = idx;
        
        if(idx>0) { //at least one buffer to process
            [self didFillDataWrapper];
        }
    }
}

-(void)addData:(float*)data withSize:(NSUInteger)length fromChannel:(NSUInteger)whichChannel withNumChannels:(NSUInteger)numChannels toBufferBlock:(DataBufferBlock*)block  {
    if(block)
        [block addInterleavedFloatData:data fromChannel:whichChannel withNumChannels:numChannels withLength:length];
    else
        NSLog(@"Could not add data to block");
}

-(DataBufferBlock*)dequeueAndTakeOwnership{
    //TODO
//    self.overlapQueue 
    return nil;
}

-(void)consumeBufferWithBlock:ConsumeBlock{
    //TODO
}

-(void)deleteAt:(NSUInteger)indexToDelete{
    [self.overlapQueue removeObjectAtIndex:indexToDelete];
}

-(void)didFillDataWrapper{
    if([self.overlapQueue count]>0){
        __block DataBufferBlock* block = [self.overlapQueue firstObject];
        
        //TODO: mutex protection? might be too slow to use here
        [self.overlapQueue removeObjectAtIndex:0];
        self.currentFillQueueIndex--;
        self.numFullBuffers--;

        if(delegateRespondsTo.didFillBuffer){
            // spin off the data into high priority queue, assuming that this data analysis needs run UI
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),^{
                [self.delegate didFillBuffer:block]; // call delegate, and it does whatever it wants with data
                //after this block executes ARC will clean up the data block for us!
                // if we have processed all buffers, set status
                if(self.numFullBuffers<=0 && delegateRespondsTo.didFinishProcessingAllBuffers){
                    [self.delegate didFinishProcessingAllBuffers];
                }
                
            });
        }
    }
}

-(void)processRemainingBlocks{
    @synchronized(self){
        while(self.numFullBuffers >0){
            // process until done
            [self didFillDataWrapper];
        }
        //TODO: block here until completion?
        [self clear]; // and clear any blocks that are not full
    }
    
}

-(void)clear{
    [self.overlapQueue removeAllObjects];
}

@end
