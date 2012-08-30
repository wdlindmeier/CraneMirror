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
    GLuint _blurProgram;

    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;

    GLuint _vertexArrayCrane;
    GLuint _vertexBufferCrane;
    
    GLuint _vertexArraySquare;
    GLuint _vertexBufferSquare;
    
    WFObject *_craneObj;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
	AVCaptureVideoDataOutput *_videoDataOutput;
	dispatch_queue_t _videoDataOutputQueue;
	UIImage *_square;
	CIDetector *_faceDetector;
    
    // FBO
    
    // Apple FBO
    GLuint framebuffer;
    GLuint fboTexture;
    GLuint colorRenderbuffer;
    int _fboWidth;
    int _fboHeight;

    // TODO: Rename
    // TODO: Remove unnecessary
    /*
    GLuint fboHandle;
    GLuint depthBuffer;
    GLuint fboTex;
    int fbo_width;
    int fbo_height;
    GLint defaultFBO;
    */
//    int uSamplerLoc;
    
    // test
    //GLuint texId;
    
    // GL context
    //EAGLContext *glContext;
    
    
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@property (nonatomic, strong) IBOutlet UIView *previewView;

@end
