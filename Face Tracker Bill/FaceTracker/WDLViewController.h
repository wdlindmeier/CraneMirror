//
//  WDLViewController.h
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>

@class CIDetector;
@class WFObject;

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

@interface WDLViewController : GLKViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    GLuint _program;

    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;

    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    WFObject *_craneObj;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
	AVCaptureVideoDataOutput *_videoDataOutput;
	dispatch_queue_t _videoDataOutputQueue;
	UIImage *_square;
	CIDetector *_faceDetector;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@property (nonatomic, strong) IBOutlet UIView *previewView;

@end
