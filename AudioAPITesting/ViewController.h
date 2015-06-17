//
//  ViewController.h
//  AudioAPITesting
//
//  Created by Mark Gill on 5/25/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSEVideoExporter.h"

@interface ViewController : UIViewController <SSEVideoExporterDelegate>

@property (strong, nonatomic) IBOutlet UISegmentedControl *mySegmentedControl;
@property (strong, nonatomic) IBOutlet UIButton *playButtonOne;
@property (strong, nonatomic) IBOutlet UIButton *playButtonTwo;
@property (strong, nonatomic) IBOutlet UIButton *videoRecordButton;

- (IBAction)buttonPressed:(id)sender;

- (IBAction)segmentedControlValueChanged:(id)sender;

- (id) init;

- (void) playSound;

@end

