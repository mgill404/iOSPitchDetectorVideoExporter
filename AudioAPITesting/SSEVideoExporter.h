//
//  SSEVideoExporter.h
//  AudioAPITesting
//
//  Created by Mark Gill on 6/15/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol SSEVideoExporterDelegate <NSObject>

- (void) videoCreatedAtPath:(NSString*)fullPath;

@end

@interface SSEVideoExporter : NSObject

@property (weak, nonatomic) id<SSEVideoExporterDelegate> delegate;

@property (strong, nonatomic, readonly) AVAssetWriter *videoWriter;

@property BOOL isRecording;

- (id) initWithDelegate:(id<SSEVideoExporterDelegate>)delegate;

- (void) startRecordingView:(UIView *)view;

- (void) stopRecording;

-(void)addAudioFile:(NSString*)audioFile ToVideo:(NSString*)videoFile withOutputFile:(NSString*)outputFile;

@end