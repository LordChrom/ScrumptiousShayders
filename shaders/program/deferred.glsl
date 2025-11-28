/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform int frameCounter;

uniform float far, near;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight, aspectRatio;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#ifdef DISTANT_HORIZONS
uniform float dhFarPlane, dhNearPlane;
uniform mat4 dhProjectionInverse;
uniform sampler2D dhDepthTex0;
#endif

//Common Variables//
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//Common Functions//
float GetLinearDepth(float depth, mat4 invProjMatrix) {
    depth = depth * 2.0 - 1.0;
    vec2 zw = depth * invProjMatrix[2].zw + invProjMatrix[3].zw;
    return -zw.x / zw.y;
}

#ifdef DISTANT_HORIZONS
float GetDHLinearDepth(float depth) {
   return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - depth * (dhFarPlane - dhNearPlane));
}
#endif

//Includes//
#include "/lib/lighting/ambientOcclusion.glsl"

//Program//
void main() {
	float blueNoise = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;
    float ao = AmbientOcclusion(blueNoise);

    #ifdef DISTANT_HORIZONS
    float z = texture2D(depthtex0, texCoord.xy).r;
    if (z == 1.0) {
        ao = DHAmbientOcclusion(blueNoise);
    }
    #endif
    
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(ao, 0.0, 0.0, 0.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif
