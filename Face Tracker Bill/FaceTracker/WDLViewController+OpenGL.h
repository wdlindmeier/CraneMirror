//
//  WDLViewController+OpenGL.h
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

#import "WDLViewController.h"


#ifndef __GL_DATA__
#define __GL_DATA__

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_DISTANCE_FLOAT,
    UNIFORM_FACE_ALPHA,
    NUM_UNIFORMS
};

enum
{
//    UNIFORM_BLUR_MODELVIEWPROJECTION_MATRIX,
//    UNIFORM_BLUR_NORMAL_MATRIX,
    UNIFORM_BLUR_SAMPLER,
    NUM_BLUR_UNIFORMS
};

GLint uniforms[NUM_UNIFORMS];
GLint blurUniforms[NUM_BLUR_UNIFORMS];

// Attribute index.
/*
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};
*/

#endif


@interface WDLViewController (OpenGL)

- (void)setupGL;
- (void)tearDownGL;
- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end
