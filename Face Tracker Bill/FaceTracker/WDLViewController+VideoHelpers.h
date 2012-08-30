//
//  WDLViewController+VideoHelpers.h
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

#import "WDLViewController.h"

// used for KVO observation of the @"capturingStillImage" property to perform flash bulb animation
static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static CGContextRef CreateCGBitmapContextForSize(CGSize size);


@interface UIImage (RotationMethods)

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;

@end


@interface WDLViewController (VideoHelpers)

@end
