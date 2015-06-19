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

@end

int midiNumberFromFrequency(float frequency);

void noteAndOctaveFromMidiNumber(int midiNumber, char note[4]);
