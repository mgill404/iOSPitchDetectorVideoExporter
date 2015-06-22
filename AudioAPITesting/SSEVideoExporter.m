//
//  SSEVideoExporter.m
//  AudioAPITesting
//
//  Created by Mark Gill on 6/15/15.
//  Copyright (c) 2015 Edify. All rights reserved.
//

#import "SSEVideoExporter.h"
#import <UIKit/UIKit.h>

@interface SSEVideoExporter ()
{
    CGAffineTransform _frameTransform;

    NSFileManager *_fileManager;
    CADisplayLink *_displayLink;
    UIView *_recordingView;
    
    BOOL _isRendering;
    
    AVAssetWriterInput* _videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_adaptor;
    CFTimeInterval _firstTimeStamp;
}

@end

@implementation SSEVideoExporter

- (id) initWithDelegate:(id<SSEVideoExporterDelegate>)delegate
{
    self = [self init];
    if(self)
    {
        self.delegate = delegate;
    }
    return self;
}

- (id) init
{
    self = [super init];
    if(self)
    {
        
        self.isRecording = NO;
        _isRendering = NO;
        _fileManager = [[NSFileManager alloc] init];
    }
    return self;
}

- (void) setupRecordToPath:(NSString *)path
{
    [self removeFile:path];
    
    NSError *error = nil;
    
    NSString *fullPath = [self documentsPath:path];
    
    if(_videoWriter)
    {
        _videoWriter = nil;
    }
    
    _videoWriter = [[AVAssetWriter alloc] initWithURL:
                    [NSURL fileURLWithPath:fullPath] fileType:AVFileTypeQuickTimeMovie
                                                error:&error];
    NSParameterAssert(_videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:_recordingView.frame.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:_recordingView.frame.size.height], AVVideoHeightKey,
                                   nil];
    
    
    _videoWriterInput = [AVAssetWriterInput
                         assetWriterInputWithMediaType:AVMediaTypeVideo
                         outputSettings:videoSettings];
    
    NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSDictionary dictionary], (id)kCVPixelBufferIOSurfacePropertiesKey,
                                           nil];
    
    
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor
                assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput
                sourcePixelBufferAttributes:pixelBufferAttributes];
    
    NSParameterAssert(_videoWriterInput);
    
    NSParameterAssert([_videoWriter canAddInput:_videoWriterInput]);
    _videoWriterInput.expectsMediaDataInRealTime = NO;
    [_videoWriter addInput:_videoWriterInput];
    
    //Start a session:
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
}

-(void) encodeImage:(CGImageRef)image
{
    //Video encoding
    CVPixelBufferRef buffer = NULL;

    buffer = [self pixelBufferFromCGImage:image];
    
    BOOL append_ok = NO;
    int j = 0;
    while (!append_ok && j < 30)
    {
        if (_adaptor.assetWriterInput.readyForMoreMediaData)
        {
            printf("appending frame attemp %d\n", j);
            
            if (!_firstTimeStamp) {
                _firstTimeStamp = _displayLink.timestamp;
            }
            CFTimeInterval elapsed = (_displayLink.timestamp - _firstTimeStamp);
            CMTime frameTime = CMTimeMakeWithSeconds(elapsed, 1000);
            
            append_ok = [_adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
            CVPixelBufferPoolRef bufferPool = _adaptor.pixelBufferPool;
            NSParameterAssert(bufferPool != NULL);
            
            [NSThread sleepForTimeInterval:0.05];
        }
        else
        {
            printf("adaptor not ready %d\n", j);
            [NSThread sleepForTimeInterval:0.05];
        }
        j++;
    }
    if (!append_ok)
    {
        printf("error appending image times %d\n", j);
    }

    CVBufferRelease(buffer);
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
   
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             [NSDictionary dictionary], (id)kCVPixelBufferIOSurfacePropertiesKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (CFDictionaryRef) CFBridgingRetain(options),
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

-(void)addAudioFile:(NSString*)audioFile ToVideo:(NSString*)videoFile withOutputFile:(NSString*)outputFile
{
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    NSString* audio_inputFilePath = [[NSBundle mainBundle] pathForResource:[audioFile stringByDeletingPathExtension] ofType:[audioFile pathExtension]];
    NSURL*    audio_inputFileUrl = [NSURL fileURLWithPath:audio_inputFilePath];
    
    NSString* video_inputFileName = videoFile;
    NSString* video_inputFilePath = [self documentsPath:video_inputFileName];
    NSURL*    video_inputFileUrl = [NSURL fileURLWithPath:video_inputFilePath];
    
    NSString* outputFileName = outputFile;
    NSString* outputFilePath = [self documentsPath:outputFileName];
    NSURL*    outputFileUrl = [NSURL fileURLWithPath:outputFilePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
    
    
    
    CMTime nextClipStartTime = kCMTimeZero;
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
    CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
    AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    _assetExport.outputFileType = @"com.apple.quicktime-movie";
    _assetExport.outputURL = outputFileUrl;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void ) {
         // [self saveVideoToAlbum:outputFilePath];
     }       
     ];  
}

- (BOOL) fileExists:(NSString*)fileName
{
    return [_fileManager fileExistsAtPath:[self documentsPath:fileName]];
}

- (void) removeFile:(NSString*)fileName
{
    if ([self fileExists:fileName]) {
        NSError *fileError;
        [_fileManager removeItemAtPath:[self documentsPath:fileName] error:&fileError];
        if (fileError){
            NSLog(@"%@", fileError.localizedDescription);
        }
    }
}

- (NSString*) documentsPath:(NSString*)fileName
{
    NSString *documentsDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [documentsDirectoryPath stringByAppendingPathComponent:fileName];
}

- (void) startRecordingView:(UIView *)view
{
    if(!view)
    {
        NSLog(@"No view to record!");
        return;
    }
    
    self.isRecording = YES;
    _recordingView = view;
    
    if(_displayLink)
    {
        [self stopRecording];
        [_displayLink invalidate];
        _displayLink = nil;
    }
    
    [self setupRecordToPath:@"TestVideo.mov"];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayUpdate)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void) displayUpdate
{
    if(_recordingView)
    {
        [self encodeImage:[self imageWithView:_recordingView].CGImage];
        NSLog(@"display updated");
    }
    else{
        [self stopRecording];
    }
}

- (UIImage *) imageWithView:(UIView *)view
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, 0);
    else
        UIGraphicsBeginImageContext(view.bounds.size);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    _frameTransform = CGContextGetCTM(UIGraphicsGetCurrentContext());
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)cleanup
{
    _adaptor = nil;
    _videoWriterInput = nil;
    _videoWriter = nil;
    _firstTimeStamp = 0;
}

- (void) stopRecording
{
    self.isRecording = NO;
    [_displayLink invalidate];
    _displayLink = nil;
    
    [_videoWriterInput markAsFinished];
    CMTime cmTime = CMTimeMake(2000, 1);
    
    [_videoWriter endSessionAtSourceTime:cmTime];
    [_videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Write Ended");
        if(self.delegate)
        {
            [self.delegate videoCreatedAtPath:@"TestVideo.mov"];
        }
        [self cleanup];
    }];
    
}

@end
