//
//  ViewController.m
//  AudioAPITesting
//
//  Created by Mark Gill on 5/25/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "ViewController.h"
#import "ObjectAL.h"
#import "AEAudioController.h"
#import "AEAudioFilePlayer.h"
#import "SSEPlaythroughChannel.h"
#import "SSEPitchDetector.h"
#import "AERecorder.h"
#import "dywapitchtrack.h"

@interface ViewController ()
{
    ALChannelSource *_channel;
    
    ALBuffer *_bufferOne;
    ALBuffer *_bufferTwo;
    ALBuffer *_selectedBuffer;

    AEAudioController *_audioController;
    AEAudioFilePlayer *_filePlayer;
    AERecorder *_playbackRecorder;
    
    // Pitch tracking objects
    SSEPlaythroughChannel *_playthroughChannel;
    dywapitchtracker pitchTracker;
    
    AEAudioFilePlayer *_tonePlayer;
    AEChannelGroupRef toneChannel;
    SSEPitchDetector *_toneTracker;
    
    NSString  *_recordedFilePath;
    
    NSTimer *_stressTimer;
    
    NSURL *_fileOne;
    NSURL *_fileTwo;
    NSURL *_selectedFile;
    
    SSEVideoExporter *_videoExporter;
}
@end

@implementation ViewController
@synthesize playButtonOne, playButtonTwo, mySegmentedControl, videoRecordButton;

- (id) init
{
    self = [super init];
    if (self)
    {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    /* --- OAL Setup --- */
    [OALSimpleAudio sharedInstance].reservedSources = 0;
    _channel = [ALChannelSource channelWithSources:64];
    _channel.interruptible = NO;    
    [OALSimpleAudio sharedInstance].context.listener.reverbOn = NO;
    [OALSimpleAudio sharedInstance].context.listener.reverbRoomType = ALC_ASA_REVERB_ROOM_TYPE_MediumRoom;
    [OALSimpleAudio sharedInstance].context.listener.globalReverbLevel = -10;
    _channel.reverbSendLevel = .25;
    
    _bufferOne = [[OpenALManager sharedInstance] bufferFromFile:@"bass_c2.caf"];
    _bufferTwo = [[OpenALManager sharedInstance] bufferFromFile:@"bass_c3.caf"];
    _selectedBuffer = _bufferOne;
    
    /* --- AAE Audio Controller --- */
    _audioController = [[AEAudioController alloc]
                            initWithAudioDescription:[AEAudioController nonInterleavedFloatStereoAudioDescription]
                            inputEnabled:YES];
    
    NSError *error = NULL;
    BOOL result = [_audioController start:&error];
    if ( !result )
    {
        // Report error
    }
    
    _fileOne = [[NSBundle mainBundle] URLForResource:@"bass_c2" withExtension:@"caf"];
    _fileTwo = [[NSBundle mainBundle] URLForResource:@"bass_c3" withExtension:@"caf"];
    _selectedFile = _fileOne;
    
    /* -- AAE Recorder --- */
    _playbackRecorder = [[AERecorder alloc] initWithAudioController:_audioController];
    
    NSString *documentsFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
                                 objectAtIndex:0];
    
    _recordedFilePath = [documentsFolder stringByAppendingPathComponent:@"Recording.aiff"];
    
    /* AAE Reverb */
    AEAudioUnitFilter *reverb = [[AEAudioUnitFilter alloc] initWithComponentDescription:
                                 AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                 kAudioUnitType_Effect,
                                                                 kAudioUnitSubType_Reverb2)
                                                                        audioController:_audioController
                                                                                  error:nil];

    [_audioController addFilter:reverb];

    [self configureAudioUnit:reverb Parameter:kReverb2Param_DryWetMix withValue:100];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_DecayTimeAt0Hz withValue:1.0];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_DecayTimeAtNyquist withValue:3.0];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_Gain withValue:-10];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_MaxDelayTime withValue:0.1];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_MinDelayTime withValue:.008];
    [self configureAudioUnit:reverb Parameter:kReverb2Param_RandomizeReflections withValue:100];
    
    // set room type
    UInt32 roomType = kReverbRoomType_SmallRoom;
    AudioUnitSetProperty(reverb.audioUnit,
                         kAudioUnitProperty_ReverbRoomType, kAudioUnitScope_Global,
                         0, &roomType, sizeof(UInt32));
    
    
    // Voice Pitch tracking setup
    
    _playthroughChannel = [[SSEPlaythroughChannel alloc] initWithAudioController:_audioController];
    dywapitch_inittracking(&pitchTracker);
    [_audioController addInputReceiver:_playthroughChannel];
    [_audioController addChannels:@[_playthroughChannel]];
     
    
    // File Pitch tracking setup
    NSURL *toneURL = [[NSBundle mainBundle] URLForResource:@"tones" withExtension:@"wav"];
    _tonePlayer = [AEAudioFilePlayer audioFilePlayerWithURL:toneURL
                                            audioController:_audioController
                                                      error:NULL];
    _tonePlayer.channelIsPlaying = NO;
    toneChannel = [_audioController createChannelGroup];
    [_audioController addChannels:@[_tonePlayer] toChannelGroup:toneChannel];
    
    _toneTracker = [[SSEPitchDetector alloc] init];
    [_audioController addOutputReceiver:_toneTracker forChannelGroup:toneChannel];
    
    // Video Exporter
    _videoExporter = [[SSEVideoExporter alloc] initWithDelegate:self];
}

- (void) configureAudioUnit:(AEAudioUnitFilter*)audioUnit Parameter:(int)param withValue:(float)value
{
    AudioUnitSetParameter(audioUnit.audioUnit,
                          kAudioUnitScope_Global,
                          0,
                          param,
                          value,
                          0.0);
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonPressed:(id)sender
{
    if(sender == playButtonOne)
    {
        _selectedBuffer = _bufferOne;
        _selectedFile   = _fileOne;
    }
    else if(sender == playButtonTwo)
    {
        _selectedBuffer = _bufferTwo;
        _selectedFile   = _fileTwo;
    }
    else if(sender == videoRecordButton)
    {
        if(_videoExporter.isRecording)
        {
            [_videoExporter stopRecording];
        }
        else
        {
            [_videoExporter startRecordingView:self.view];
        }
    }
    [self playSound];
}

- (void) playSound
{
    switch (mySegmentedControl.selectedSegmentIndex)
    {
        case 0:
        {
            [self playSoundOAL];
            break;
        }
        case 1:
        {
            [self playSoundAAE];
            break;
        }
        case 2:
            _tonePlayer.channelIsPlaying = YES;
            break;
            
        default:
            break;
    }
}

- (void) playSoundOAL
{
    [_channel play:_selectedBuffer gain:1.0 pitch:1 pan:0 loop:NO];
}

- (void) playSoundAAE
{
    _filePlayer = [AEAudioFilePlayer audioFilePlayerWithURL:_selectedFile
                                            audioController:_audioController
                                                      error:NULL];
    _filePlayer.removeUponFinish = YES;
    
    [_filePlayer setVolume:0.8];
    
    [_audioController addChannels:[NSArray arrayWithObject:_filePlayer]];
    
}

- (void) playSoundIHAE
{
    
}

- (IBAction)segmentedControlValueChanged:(id)sender
{
}

- (void) videoCreatedAtPath:(NSString *)path
{
    [_videoExporter addAudioFile:@"tones.wav"
                         ToVideo:path
                  withOutputFile:[NSString stringWithFormat:@"final_%@",path]];
}
@end
