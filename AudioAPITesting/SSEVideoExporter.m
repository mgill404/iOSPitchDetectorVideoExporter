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
    NSMutableArray *_pictArray;
    NSFileManager *_fileManager;
    CADisplayLink *_displayLink;
    UIView *_recordingView;
    
    BOOL _isRendering;
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
        
        _pictArray = [[NSMutableArray alloc] init];
        self.isRecording = NO;
        _isRendering = NO;
        _fileManager = [[NSFileManager alloc] init];
    }
    return self;
}

-(void) writeImagesToMovieAtPath:(NSString *)path withVideoLengthInSeconds:(float) videoLength
{
    if(_pictArray.count == 0)
    {
        NSLog(@"No images to create video!");
        return;
    }
    
    UIImage *image = [_pictArray objectAtIndex:0];
    
    [self removeFile:path];
    
    NSLog(@"Write Started");
    
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
                                   [NSNumber numberWithInt:image.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:image.size.height], AVVideoHeightKey,
                                   nil];
    
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:videoSettings];
    
    
    
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                     sourcePixelBufferAttributes:nil];
    
    NSParameterAssert(videoWriterInput);
    
    NSParameterAssert([_videoWriter canAddInput:videoWriterInput]);
    videoWriterInput.expectsMediaDataInRealTime = NO;
    [_videoWriter addInput:videoWriterInput];
    //Start a session:
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    
    //Video encoding
    
    CVPixelBufferRef buffer = NULL;
    NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSDictionary dictionary], (id)kCVPixelBufferIOSurfacePropertiesKey,
                                           nil];
    int frameCount = 0;
    float miilisecondsPerImage = 1000*(videoLength/_pictArray.count);
    for(int i = 0; i<_pictArray.count; i++)
    {
        
        UIImage *img = [_pictArray objectAtIndex:i];
        
        buffer = [self pixelBufferFromCGImage:img.CGImage];
        
        {
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
            
            CIContext *temporaryContext = [CIContext contextWithOptions:nil];
            CGImageRef videoImage = [temporaryContext
                                     createCGImage:ciImage
                                     fromRect:CGRectMake(0, 0,
                                                         CVPixelBufferGetWidth(buffer),
                                                         CVPixelBufferGetHeight(buffer))];
            
            UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
            CGImageRelease(videoImage);
        }
        
        BOOL append_ok = NO;
        int j = 0;
        while (!append_ok && j < 30)
        {
            if (adaptor.assetWriterInput.readyForMoreMediaData)
            {
                printf("appending %d attemp %d\n", frameCount, j);
                
                CMTime frameTime = CMTimeMake(frameCount*miilisecondsPerImage,(int32_t) 1000);
                
                append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                CVPixelBufferPoolRef bufferPool = adaptor.pixelBufferPool;
                NSParameterAssert(bufferPool != NULL);
                
                [NSThread sleepForTimeInterval:0.05];
            }
            else
            {
                printf("adaptor not ready %d, %d\n", frameCount, j);
                [NSThread sleepForTimeInterval:0.05];
            }
            j++;
        }
        if (!append_ok)
        {
            printf("error appending image %d times %d\n", frameCount, j);
        }
        frameCount++;
        CVBufferRelease(buffer);
    }
    
    [videoWriterInput markAsFinished];
    CMTime cmTime = CMTimeMake(2000, 1);
    [_videoWriter endSessionAtSourceTime:cmTime];
    [_videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Write Ended");
        if(self.delegate)
        {
            [self.delegate videoCreatedAtPath:path];
        }
    }];
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
    
    // NSString* audio_inputFileName = audioFile;
    // NSString* audio_inputFilePath = [self documentsPath:audio_inputFileName];
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
    [_pictArray removeAllObjects];
    
    if(_displayLink)
    {
        [self stopRecording];
        [_displayLink invalidate];
        _displayLink = nil;
    }
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayUpdate)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void) displayUpdate
{
    if(_recordingView)
    {
        [_pictArray addObject:[self imageWithView:_recordingView]];
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

- (void) stopRecording
{
    self.isRecording = NO;
    [_displayLink invalidate];
    _displayLink = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self writeImagesToMovieAtPath:@"videoTest.mov"
              withVideoLengthInSeconds:_pictArray.count/60.0];
    });
}

@end
