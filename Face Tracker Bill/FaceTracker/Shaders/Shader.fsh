//
//  Shader.fsh
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
