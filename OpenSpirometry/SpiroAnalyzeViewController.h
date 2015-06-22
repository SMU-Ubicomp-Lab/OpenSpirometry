//
//  ViewController.h
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#import "SpirometerEffortAnalyzer.h"

@interface SpiroAnalyzeViewController : UIViewController <SpirometerEffortDelegate, MFMailComposeViewControllerDelegate>

- (IBAction)openMailDialog:(id)sender;

@end

