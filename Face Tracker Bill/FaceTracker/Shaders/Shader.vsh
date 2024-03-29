//
//  Shader.vsh
//  FaceTracker
//
//  Created by William Lindmeier on 8/26/12.
//  Copyright (c) 2012 William Lindmeier. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;
uniform float distanceFloat;
uniform float faceAlpha;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 2.0, 0.0);
//    vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
    vec4 diffuseColor = vec4(0.9, 0.9, 0.9, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
//    colorVarying = diffuseColor * nDotVP;
    colorVarying = ((1.0 + (diffuseColor * nDotVP)) * 0.5) * (1.0-distanceFloat);
    
    // Fade w/out alpha:
    colorVarying = colorVarying * faceAlpha;

    // Fade w/ alpha:
    //colorVarying.a = faceAlpha;
    
    gl_Position = modelViewProjectionMatrix * position;
}
