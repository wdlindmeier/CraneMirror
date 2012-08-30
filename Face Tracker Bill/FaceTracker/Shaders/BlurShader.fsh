varying highp vec2 textureCoordinate;
varying lowp vec4 colorVarying;
uniform sampler2D videoFrame;

void main()
{
    lowp vec4 texColor = texture2D(videoFrame, textureCoordinate);
    //texColor.r = 1.0;
    //texColor.b = 0.0;
    gl_FragColor = texColor;
    
//    gl_FragColor = colorVarying;
}