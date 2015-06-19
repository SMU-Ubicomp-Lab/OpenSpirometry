//
//  ViewController.m
//  OpenSpirometry
//
//  Created by Eric Larson 
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// here is a super simple implementation of using the analyzer

#import "SpiroAnalyzeViewController.h"
#import "SpirometerEffortAnalyzer.h"

@interface SpiroAnalyzeViewController ()

@property (weak, nonatomic) IBOutlet UISlider *flowSlider;
@property (weak, nonatomic) IBOutlet UILabel *feedbackLabel;
@property (weak, nonatomic) IBOutlet UILabel *flowLabel;

// our model of the spirometry analysis for one effort
@property (strong, nonatomic) SpirometerEffortAnalyzer* spiro;

@end

@implementation SpiroAnalyzeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.spiro = [[SpirometerEffortAnalyzer alloc] init];
    self.spiro.delegate = self;
    self.spiro.prefferredAudioMaxUpdateIntervalInSeconds = 1.0/24.0; // the default is 30FPS, so setting lower
    // the FPS possible on this depends on the audio buffer size and sampling rate, which is different for different phones
    // most likely this has a maximum update rate of about 100 FPS
    
}

#pragma mark IBActions From View
- (IBAction)startEffort:(UIButton *)sender {
    self.feedbackLabel.text = @"Calibrating sound, please remain silent...";
    self.flowSlider.value = 0;
    [self.spiro beginListeningForEffort];
}

- (IBAction)getPermission:(UIButton *)sender {
    [self.spiro askPermissionToUseAudioIfNotDone];
}
- (IBAction)cancelEffort:(UIButton *)sender {
    [self.spiro requestThatCurrentEffortShouldCancel];
}
- (IBAction)overrideEffort:(UIButton *)sender {
    // this function is used for overriding the automatic "end" of the effort
    // you can use it immediately end the effort
    [self.spiro requestThatEffortShouldEnd];
}

#pragma mark SpirometerDelegate Methods
// all delegate methods are called from the main queue for UI updates
// as such, you should add the operation to another queue if it is not UI related
-(void)didFinishCalibratingSilence{
    self.feedbackLabel.text = @"Inhale deeply ...and blast out air when ready!";
}

-(void)didTimeoutWaitingForTestToStart{
    self.feedbackLabel.text = @"No exhale heard, effort canceled";
}

-(void)didStartExhaling{
    self.feedbackLabel.text = @"Keep blasting!!";
}

-(void)willEndTestSoon{
    self.feedbackLabel.text = @"Try to push last air out!! Go, Go, Go!";
}

-(void)didCancelEffort{
    self.feedbackLabel.text = @"Effort Cancelled";
}


-(void)didEndEffortWithResults:(NSDictionary*)results{
    // right now results are an empty dictionary
    // in the future the results of the effort will all be stored as key/value pairs
    NSLog(@"%@",results);
    self.feedbackLabel.text = @"Effort Complete. Thanks!";
}

-(void)didUpdateFlow:(float)flow andVolume:(float)volume{
    // A calibrated flow measurement that will come back dynamically and some time after the flow is detected
    // flow and volume are just placeholders right now
    // the value of "flow" will change, but it is not converted to an actual flow rate yet
    // volume is always zero right now
    
    self.flowSlider.value = flow; // watch it jump around when updated
    self.flowLabel.text = [NSString stringWithFormat:@"Flow: %.2f",flow];
}

-(void)didUpdateAudioBufferWithMaximum:(float)maxAudioValue{
    // once silence has been calibrated, you will start getting this message
    // This happens many times per second, depending on the preferred time interval (default is 30 times per scond)
    // for updating a game UI quickly, this is the better option but does not give you a valid flow rate
    NSLog(@"Audio Max: %.4f", maxAudioValue);
}

@end
