//
//  CubicSpline.m
//  CubicSpline
//
//  Created by Sam Soffes on 12/16/13.
//  Copyright (c) 2013-2014 Sam Soffes. All rights reserved.
//

#import "CubicSpline.h"

@interface CubicSpline ()
@property (nonatomic, strong) NSArray *x;
@property (nonatomic, strong) NSArray *y;
@property (nonatomic, strong) NSArray *b;
@property (nonatomic, strong) NSArray *c;
@property (nonatomic, strong) NSArray *d;
@end

@implementation CubicSpline

- (instancetype)initWithPointsX:(NSArray *)x andY:(NSArray *)y {
	if ((self = [super init])) {
		self.x = x;
        self.y = y;

		if (x.count > 0) {
			NSUInteger count = x.count;
			NSUInteger n = count; // - 1;
			float x[count];
			float a[count];
			float h[count];
			float y[count];
			float l[count];
			float u[count];
			float z[count];
			float k[count];
			float s[count];

			for (NSUInteger i = 0; i < self.x.count; i++) {
				x[i] = [self.x[i] floatValue];
				a[i] = [self.y[i] floatValue];
			}

			for (NSUInteger i = 0; i < n; i++) {
				h[i] = x[i + 1] - x[i];
				k[i] = a[i + 1] - a[i];
				s[i] = k[i] / h[i];
			}

			for (NSUInteger i = 1; i < n; i++) {
				y[i] = 3 / h[i] * (a[i + 1] - a[i]) - 3 / h[i - 1] * (a[i] - a[i - 1]);
			}

			l[0] = 1;
			u[0] = 0;
			z[0] = 0;

			for (NSUInteger i = 1; i < n; i++) {
				l[i] = 2 * (x[i + 1] - x[i - 1]) - h[i - 1] * u[i - 1];
				u[i] = h[i] / l[i];
				z[i] = (y[i] - h[i - 1] * z[i - 1]) / l[i];
			}

			l[n] = 1;
			z[n] = 0;

			NSMutableArray *b = [[NSMutableArray alloc] initWithCapacity:n];
			NSMutableArray *c = [[NSMutableArray alloc] initWithCapacity:n];
			NSMutableArray *d = [[NSMutableArray alloc] initWithCapacity:n];

			for (NSUInteger i = 0; i <= n; i++) {
				b[i] = @0;
				c[i] = @0;
				d[i] = @0;
			}

			for (NSInteger i = n - 1; i >= 0; i--) {
				c[i] = @(z[i] - u[i] * [c[i + 1] floatValue]);
				b[i] = @((a[i + 1] - a[i]) / h[i] - h[i] * ([c[i + 1] floatValue] + 2.0f * [c[i] floatValue]) / 3.0f);
				d[i] = @(([c[i + 1] floatValue] - [c[i] floatValue]) / (3 * h[i]));
			}

			c[n] = @0;

			self.b = b;
			self.c = c;
			self.d = d;
		}
	}
	return self;
}


- (float)interpolateX:(float)input {
	if (self.x.count == 0) {
		// No points. Return identity.
		return input;
	}

	float x[self.x.count];
	float a[self.x.count];

	for (NSUInteger i = 0; i < self.x.count; i++) {
		x[i] = [self.x[i] floatValue];
		a[i] = [self.y[i] floatValue];
	}

	NSInteger i = 0;
	for (i = self.x.count - 1; i > 0; i--) {
		if (x[i] <= input) {
			break;
		}
	}

	float deltaX = input - x[i];
	return a[i] + [self.b[i] floatValue] * deltaX + [self.c[i] floatValue] * pow(deltaX, 2) + [self.d[i] floatValue] * pow(deltaX, 3);
}

@end
