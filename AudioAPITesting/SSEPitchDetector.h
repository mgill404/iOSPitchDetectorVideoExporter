//
//  SSEAudioReceiver.h
//  AudioAPITesting
//
//  Created by Mark Gill on 6/15/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AEAudioController.h"

@interface SSEPitchDetector : NSObject <AEAudioReceiver>

- (id) initWithAudioController:(AEAudioController *)audioController;

- (int) midiNumberFromFrequency:(float) frequency;

- (NSString*) noteAndOctaveFromMidiNumber:(int)midiNumber;

@end
