//
//  WDLViewController.m
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

#import "WDLViewController.h"
#import "WDLViewController+OpenGL.h"
#import "WDLViewController+VideoHelpers.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import "WFObject.h"


@implementation WDLViewController
{
    NSTimeInterval _timeStarted;
    GLKVector3     _vecFace;
    GLKVector3     _vecDelta;
    float          _prevFaceDist;
    float          _faceAlpha;
    int            _numFacelessFrames;
    
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    // NOTE:
    // This doesn't help use because we're drawing in the FBO
//    view.drawableMultisample = GLKViewDrawableMultisample4X;
    
    _faceAlpha = 0.0f;
    
    _craneObj = [[WFObject alloc] initWithFilename:@"crane"];
    
    [self setupGL];
    
    _square = [UIImage imageNamed:@"squarePNG"];
    
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
	_faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                       context:nil
                                       options:detectorOptions];
    
    
    _previewView.hidden = YES;

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self setupAVCapture];
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    [self teardownAVCapture];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
	self.context = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

#pragma mark - Video Session

- (void)setupAVCapture
{
    _timeStarted = [NSDate timeIntervalSinceReferenceDate];
    
	NSError *error = nil;
	
	AVCaptureSession *session = [AVCaptureSession new];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	    [session setSessionPreset:AVCaptureSessionPreset640x480];
	else
	    [session setSessionPreset:AVCaptureSessionPresetPhoto];
	
    // Select a video device, make an input
	AVCaptureDevice *device = [self frontFacingCameraIfAvailable];//[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                              error:&error];
	if ( [session canAddInput:deviceInput] )
            [session addInput:deviceInput];
	
    // Make a video data output
	_videoDataOutput = [AVCaptureVideoDataOutput new];
	
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
	NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                                                  forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	[_videoDataOutput setVideoSettings:rgbOutputSettings];
	[_videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked (as we process the still image)
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
	_videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[_videoDataOutput setSampleBufferDelegate:self
                                        queue:_videoDataOutputQueue];
	
    if ([session canAddOutput:_videoDataOutput] )
		[session addOutput:_videoDataOutput];
    
	[[_videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
	
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[_previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	CALayer *rootLayer = [_previewView layer];
	[rootLayer setMasksToBounds:YES];
	[_previewLayer setFrame:[rootLayer bounds]];
	[rootLayer addSublayer:_previewLayer];
    
	[session startRunning];
    
}

// clean up capture setup
- (void)teardownAVCapture
{
    _videoDataOutput = nil;
	if (_videoDataOutputQueue)
		dispatch_release(_videoDataOutputQueue);
	[_previewLayer removeFromSuperlayer];
    _previewLayer = nil;
}

- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    //  look at all the video devices and get the first one that's on the front
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            captureDevice = device;
            break;
        }
    }
    
    //  couldn't find one on the front, so just get the default video device.
    if ( ! captureDevice)
    {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    return captureDevice;
}

// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
	
	CGRect videoBox;
	videoBox.size = size;
	if (size.width < frameSize.width)
		videoBox.origin.x = (frameSize.width - size.width) / 2;
	else
		videoBox.origin.x = (size.width - frameSize.width) / 2;
	
	if ( size.height < frameSize.height )
		videoBox.origin.y = (frameSize.height - size.height) / 2;
	else
		videoBox.origin.y = (size.height - frameSize.height) / 2;
    
	return videoBox;
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
// to detect features and for each draw the red square in a layer and set appropriate orientation
- (void)drawFaceBoxesForFeatures:(NSArray *)features forVideoBox:(CGRect)clap orientation:(UIDeviceOrientation)orientation
{
    /* // FPS
    NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
    float numSecs = ti - _timeStarted;
    _timeStarted = ti;
    float fps = 1.0/numSecs;
    NSLog(@"fps: %f", fps);
    */
    
	NSArray *sublayers = [NSArray arrayWithArray:[_previewLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [features count], currentFeature = 0;
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// hide all the face layers
	for ( CALayer *layer in sublayers ) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}
	
	if ( featuresCount == 0) {
        
        _numFacelessFrames++;
        
        if(_numFacelessFrames > 10){
            // Make the face more transparent
            _faceAlpha *= 0.95;
        }
        
		[CATransaction commit];
        
        // Just give it a little jiggle so it doesn't look so dead.
        // heh.
        float decay = 0.6;
        _vecDelta = GLKVector3Make(_vecDelta.x * decay, _vecDelta.y * decay, _vecDelta.z * decay);

        _vecFace = GLKVector3Make(_vecFace.x + _vecDelta.x + (float)(((arc4random() % 200) - 100.0f) * 0.00005f),
                                  _vecFace.y + _vecDelta.y + (float)(((arc4random() % 200) - 100.0f) * 0.00005f),
                                  _vecFace.z);

		return; // early bail.
	}
    
    _numFacelessFrames = 0;
    
    // Make the face more opaque
    _faceAlpha += (1.0-_faceAlpha) * 0.025;
    
	CGSize parentFrameSize = [_previewView frame].size;
	NSString *gravity = [_previewLayer videoGravity];
	BOOL isMirrored = [_previewLayer isMirrored];
	CGRect previewBox = [WDLViewController videoPreviewBoxForGravity:gravity
                                                           frameSize:parentFrameSize
                                                        apertureSize:clap.size];
	
    for ( CIFaceFeature *ff in features ) {
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];
        
        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        
        if ( isMirrored )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
        else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        
        
        // Set the rotation based on the faceRect
        // NOTE:
        // This can only track 1 face
        CGPoint faceOrigin = CGPointMake(faceRect.origin.x + (faceRect.size.width * 0.5),
                                         faceRect.origin.y + (faceRect.size.height* 0.5));
        
        float halfWidth = previewBox.size.width * 0.5;
        float halfHeight = previewBox.size.height * 0.5;

        float scalarX = (faceOrigin.x - halfWidth) / halfWidth;
        float scalarY = (faceOrigin.y - halfHeight) / halfHeight;
        float scalarZ = faceRect.size.width / previewBox.size.width;
        
        GLKVector3 vecCam = GLKVector3Make(scalarX, scalarY, scalarZ);
        
        _vecDelta = GLKVector3Make(vecCam.x - _vecFace.x, vecCam.y - _vecFace.y, vecCam.z - _vecFace.z);
        
        // average the vecs so it doesn't look too choppy
        int numAvgs = 3;
        _vecFace = GLKVector3Make((vecCam.x + (_vecFace.x * numAvgs)) / (numAvgs + 1),
                                  (vecCam.y + (_vecFace.y * numAvgs)) / (numAvgs + 1),
                                  (vecCam.z + (_vecFace.z * numAvgs)) / (numAvgs + 1));
        

                
        CALayer *featureLayer = nil;
        
        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }
        
        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [CALayer new];
            [featureLayer setContents:(id)[_square CGImage]];
            [featureLayer setName:@"FaceLayer"];
            [_previewLayer addSublayer:featureLayer];
        }
        [featureLayer setFrame:faceRect];
        
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                break;
            case UIDeviceOrientationLandscapeLeft:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
                break;
            case UIDeviceOrientationLandscapeRight:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                break; // leave the layer in its last known orientation
        }
        currentFeature++;
    }
    
	[CATransaction commit];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	// got an image
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
	if (attachments)
		CFRelease(attachments);
	NSDictionary *imageOptions = nil;
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	int exifOrientation;
	
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
	};
	
	switch (curDeviceOrientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			//if (isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			//else
			//	exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			//if (isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			//else
			//	exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    
	imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
	NSArray *features = [_faceDetector featuresInImage:ciImage options:imageOptions];
	
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
	CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaceBoxesForFeatures:features forVideoBox:clap orientation:curDeviceOrientation];
	});
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{

    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    // NOTE:
    // We want the base to be set back far enough that the crane fills the whole
    // screen. (e.g. a unit of 1)
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -3.0f);
    
    
    // Hand-tweak the matrix for the crane model.
    // TODO: Can this be done on a model-by-model basis?
    // Scale
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeScale(0.05, 0.05, 0.05);
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 10.0, -20.0, 0.0);
    
    // TEST
    // The closer you are to the edge, the less it moves
    // NOTE:
    // This should probably look at the edge of the face bounds rather than
    // the center because the cam stops tracking the face when the edge goes off.
    float xyzWeight = 1.24f; //1.25
    float xWeight = xyzWeight;//(1.0 - fabs(_vecFace.y)) * xyzWeight;
    float yWeight = xyzWeight;//(1.0 - fabs(_vecFace.x)) * xyzWeight;

    // Z
    // modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _vecFace.z, 0.0f, 0.0f, 1.0f);
    
    // Calibrate a little bit, because the face will never be 1.0
    float minCap = 0.0;
    float maxCap = 0.5;
    float capRange = maxCap - minCap;
    float clampedZ = MIN(MAX(_vecFace.z, minCap), maxCap);
    float calibratedZ = (clampedZ-minCap) / capRange;

    float faceDist = (1.0-calibratedZ);
    int numDistAvgs = 10;
    float frameDist = ((_prevFaceDist*numDistAvgs) + faceDist) / (numDistAvgs+1);
    _prevFaceDist = frameDist;

    float maxDist = -400.0f;
    float actualZDist = frameDist * maxDist;
    
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0, 0, actualZDist);
    
    // X
    float rotX = _vecFace.y * -1 * _vecFace.z * xWeight;
    // Flip for orientation
    
    // NOTE: This is crane only.
    rotX += DegreesToRadians(12.5f);
    
    // Y
    float rotY = _vecFace.x * -1 * _vecFace.z * yWeight;
    
    if(self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        rotX = rotX * -1;
        rotY = rotY * -1;
    }
    
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotX, 1.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotY, 0.0f, 1.0f, 0.0f);
    
    // Adjust for the default crane orientation. 
    // TODO: Can this be done on a model-by-model basis?
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, DegreesToRadians(10.0), 0.0f, 1.0f, 0.0f);
    
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);

    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
}

- (void)renderFBO
{
    
    // Start the framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);    
    
    // The Good Stuff

    glViewport(0,0, _fboWidth, _fboHeight);
    
    const static BOOL FadeWithAlpha = NO; // IMPORTANT: Also change the shader
    
    if(FadeWithAlpha){
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    }else{
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    }

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    // Load up the vertext data
    glBindVertexArrayOES(_vertexArrayCrane);
    
    if(FadeWithAlpha){
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    //glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniform1f(uniforms[UNIFORM_DISTANCE_FLOAT], _prevFaceDist);
    glUniform1f(uniforms[UNIFORM_FACE_ALPHA], _faceAlpha);
    
    //    glDrawArrays(GL_TRIANGLES, 0, 108);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, _craneObj.numVerts);

    // Render to FPO texture
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fboTexture, 0);
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [self renderFBO];
 
    // reset to main framebuffer
    [((GLKView *) self.view) bindDrawable];

    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArraySquare);
    
    glUseProgram(_blurProgram);
    
    // Binding the tex

    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fboTexture);
    glUniform1i(blurUniforms[UNIFORM_BLUR_SAMPLER], 0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

}

@end
