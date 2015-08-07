//
//  CubicSpline.h
//  CubicSpline
//
//  Created by Sam Soffes on 12/16/13.
//  Copyright (c) 2013-2014 Sam Soffes. All rights reserved.
// Manipulated from https://github.com/soffes/SAMCubicSpline
// Updated by Dr. Eric Larson July 2015

#import <Foundation/Foundation.h>


@interface CubicSpline : NSObject

/**
 Initialize a new cubic spline.

 @param points An array of `NSValue` objects containing `x and y` structs. These points are the control points of the curve.

 @return A new cubic spline.
 */
- (instancetype)initWithPointsX:(NSArray *)x andY:(NSArray *)y;

/**
 Input an X value between 0 and 1.

 @return The corresponding Y value.
 */
- (float)interpolateX:(float)x;

@end
