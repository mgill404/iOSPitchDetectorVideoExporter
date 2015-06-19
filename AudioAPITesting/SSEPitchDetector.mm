//
//  SSEPitchDetector.m
//  AudioAPITesting
//
//  Created by Mark Gill on 6/15/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import "SSEPitchDetector.h"
#import "SSEEnvelopeDetector.h"
#import "dywapitchtrack.h"
#import "stdio.h"

@interface SSEPitchDetector ()
{
    dywapitchtracker _pitchTracker;
    SSEEnvelopeDetector _envelopeDetector;
    NSArray* _noteNames;
}
@end

@implementation SSEPitchDetector

- (id) initWithAudioController:(AEAudioController *)audioController
{
    self = [super init];
    if(self)
    {
        _noteNames = [[NSArray alloc] initWithObjects:@"C",@"Db",@"D",@"Eb",@"E",@"F",@"Gb",@"G",@"Ab",@"A",@"Bb",@"B",nil];
        dywapitch_inittracking(&_pitchTracker);
        _envelopeDetector.init(audioController.audioDescription.mSampleRate, 20, 20, false, 0, false);
    }
    return self;
}

static void receiverCallback(__unsafe_unretained SSEPitchDetector *THIS,
                             __unsafe_unretained AEAudioController *audioController,
                             void *source,
                             const AudioTimeStamp *time,
                             UInt32 frames,
                             AudioBufferList *audio)
{
    dywapitchtracker* tracker = &THIS->_pitchTracker;
    SSEEnvelopeDetector *envDetector = &THIS->_envelopeDetector;
    
    float *samples = (float*)audio->mBuffers[0].mData;
    double pitchEstimate = dywapitch_computepitch(tracker, samples, 0, frames);
    static double pitch = 0;
    if(pitchEstimate != 0)
    {
        float envelope = envDetector->detect(samples, frames);
        if(envelope > 0.01)
        {
            pitch = pitchEstimate;
            char note[4];
            // NSLog(@"Rec. Note: %f", pitch);
            noteAndOctaveFromMidiNumber(midiNumberFromFrequency(pitch), note);
            NSLog(@"Rec. Note: %c%c%c%c\n", note[0],note[1],note[2],note[3]);
        }
    }
}

- (int) midiNumberFromFrequency:(float) frequency
{
    return roundf(12*log2(frequency/440) + 69);
}

- (NSString*) noteAndOctaveFromMidiNumber:(int)midiNumber
{
    int octave = (midiNumber / 12) - 1;
    return [NSString stringWithFormat:@"%@%d",[_noteNames objectAtIndex:midiNumber%12],octave];
}

int midiNumberFromFrequency(float frequency)
{
    return roundf(12*log2(frequency/440) + 69);
}

void noteAndOctaveFromMidiNumber(int midiNumber, char note[4])
{
    static char notes[24] = {'C',' ','D','b','D',' ','E','b','E',' ','F',' ','G','b','G',' ','A','b','A',' ','B','b','B',' '};
    static char octaves[7] = {'0','1','2','3','4','5','6'};
    int index = (midiNumber%12)*2;
    
    note[0] = notes[index];
    note[1] = notes[index+1];
    note[2] = ' ';
    note[3] = octaves[(midiNumber / 12) - 1];
    
    return;
}

-(AEAudioControllerAudioCallback)receiverCallback
{
    return (AEAudioControllerAudioCallback) receiverCallback;
}

@end
