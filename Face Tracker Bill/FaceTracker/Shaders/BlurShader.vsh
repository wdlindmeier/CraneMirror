attribute vec4 position;
attribute vec3 normal;
//attribute vec4 inputTextureCoordinate;
attribute vec4 texCoord;
varying lowp vec4 colorVarying;

varying vec2 textureCoordinate;

void main()
{
    // Kill the warning
    vec3 n = normal;
    
    gl_Position = position;
    textureCoordinate = texCoord.xy; //inputTextureCoordinate.xy;
//    textureCoordinate = inputTextureCoordinate.xy;
    
    colorVarying = vec4(0.0,1.0,1.0,1.0);
}