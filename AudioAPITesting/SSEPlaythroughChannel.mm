//
//  SSEPlaythroughChannel.m
//  AudioAPITesting
//
//  Created by Mark Gill on 6/15/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import "SSEPlaythroughChannel.h"
#import "SSEEnvelopeDetector.h"
#import "dywapitchtrack.h"

@interface SSEPlaythroughChannel()
{
    dywapitchtracker _pitchTracker;
    SSEEnvelopeDetector _envelopeDetector;
}
@end

@implementation SSEPlaythroughChannel

- (id) initWithAudioController:(AEAudioController *)audioController
{
    self = [super initWithAudioController:audioController];
    if(self)
    {
        dywapitch_inittracking(&_pitchTracker);
        _envelopeDetector.init(audioController.audioDescription.mSampleRate, 20, 100, false, 0, false);
    }
    return self;
}

static void receiverCallback(__unsafe_unretained SSEPlaythroughChannel *THIS,
                             __unsafe_unretained AEAudioController *audioController,
                             void *source,
                             const AudioTimeStamp *time,
                             UInt32 frames,
                             AudioBufferList *audio) {
    dywapitchtracker* tracker = &THIS->_pitchTracker;
    SSEEnvelopeDetector *envDetector = &THIS->_envelopeDetector;
    
    float *samples = (float*)audio->mBuffers[0].mData;
    double pitchEstimate = dywapitch_computepitch(tracker, samples, 0, frames);
    static double pitch = 0;
    if(pitchEstimate != 0)
    {
        float envelope = envDetector->detect(samples, frames);
        if(envelope > 0.02)
        {
            pitch = pitchEstimate;
            NSLog(@"Live Pitch: %f", pitch);
        }
    }
}

-(AEAudioControllerAudioCallback)receiverCallback {
    return (AEAudioControllerAudioCallback) receiverCallback;
}

@end
