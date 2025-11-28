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

varying vec3 sunVec, upVec, eastVec;

//Uniforms//
uniform int bedrockLevel;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int worldTime;

uniform float blindFactor, darknessFactor, nightVision;
uniform float cloudHeight;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#ifdef AO
uniform sampler2D colortex4;
#endif

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
uniform vec3 previousCameraPosition;

uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#endif

#ifdef MCBL_SS
uniform sampler2D colortex8;
uniform sampler2D colortex9;
#endif

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
uniform float dhFarPlane, dhNearPlane;

uniform mat4 dhProjection, dhProjectionInverse;

uniform sampler2D dhDepthTex0;
#endif

//Optifine Constants//
#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
const bool colortex0MipmapEnabled = true;
const bool colortex5MipmapEnabled = true;
const bool colortex6MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

vec2 aoSampleOffsets[4] = vec2[4](
	vec2( 1.5,  0.5),
	vec2(-0.5,  1.5),
	vec2(-1.5, -0.5),
	vec2( 0.5, -1.5)
);

vec2 aoDepthOffsets[4] = vec2[4](
	vec2( 2.0,  1.0),
	vec2(-1.0,  2.0),
	vec2(-2.0, -1.0),
	vec2( 1.0, -2.0)
);

vec2 glowOffsets[16] = vec2[16](
    vec2( 0.0, -1.0),
    vec2(-1.0,  0.0),
    vec2( 1.0,  0.0),
    vec2( 0.0,  1.0),
    vec2(-1.0, -2.0),
    vec2( 0.0, -2.0),
    vec2( 1.0, -2.0),
    vec2(-2.0, -1.0),
    vec2( 2.0, -1.0),
    vec2(-2.0,  0.0),
    vec2( 2.0,  0.0),
    vec2(-2.0,  1.0),
    vec2( 2.0,  1.0),
    vec2(-1.0,  2.0),
    vec2( 0.0,  2.0),
    vec2( 1.0,  2.0)
);

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth, mat4 invProjMatrix) {
    depth = depth * 2.0 - 1.0;
    vec2 zw = depth * invProjMatrix[2].zw + invProjMatrix[3].zw;
    return -zw.x / zw.y;
}

float GetNonLinearDepth(float linDepth, mat4 projMatrix) {
    vec2 zw = -linDepth * projMatrix[2].zw + projMatrix[3].zw;
    return (zw.x / zw.y) * 0.5 + 0.5;
}

#ifdef AO
float GetAmbientOcclusion(float z){
	float ao = 0.0;
	float tw = 0.0;
	float lz = GetLinearDepth(z, gbufferProjectionInverse);
	
	for(int i = 0; i < 4; i++){
		vec2 sampleOffset = aoSampleOffsets[i] / vec2(viewWidth, viewHeight);
		vec2 depthOffset = aoDepthOffsets[i] / vec2(viewWidth, viewHeight);
		float samplez = GetLinearDepth(texture2D(depthtex0, texCoord + depthOffset).r, gbufferProjectionInverse);
		float wg = max(1.0 - 4.0 * abs(lz - samplez), 0.00001);
		ao += texture2D(colortex4, texCoord + sampleOffset).r * wg;
		tw += wg;
	}
	ao /= tw;
	if(tw < 0.0001) ao = texture2D(colortex4, texCoord).r;
	
	return pow(ao, AO_STRENGTH);
}

#ifdef DISTANT_HORIZONS
float GetDHLinearDepth(float depth) {
   return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - depth * (dhFarPlane - dhNearPlane));
}

float GetDHAmbientOcclusion(float dhZ){
	float ao = 0.0;
	float tw = 0.0;
	float lz = GetLinearDepth(dhZ, dhProjectionInverse);
	
	for(int i = 0; i < 4; i++){
		vec2 sampleOffset = aoSampleOffsets[i] / vec2(viewWidth, viewHeight);
		vec2 depthOffset = aoDepthOffsets[i] / vec2(viewWidth, viewHeight);
		float samplez = GetLinearDepth(texture2D(dhDepthTex0, texCoord + depthOffset).r, dhProjectionInverse);
		float wg = max(1.0 - 4.0 * abs(lz - samplez), 0.00001);
		ao += texture2D(colortex4, texCoord + sampleOffset).r * wg;
		tw += wg;
	}
	ao /= tw;
	if(tw < 0.0001) ao = texture2D(colortex4, texCoord).r;
	
	return pow(ao, AO_STRENGTH + 1.0);
}
#endif
#endif

void GlowOutline(inout vec3 color){
	for(int i = 0; i < 16; i++){
		vec2 glowOffset = glowOffsets[i] / vec2(viewWidth, viewHeight);
		float glowSample = texture2D(colortex3, texCoord.xy + glowOffset).b;
		if(glowSample < 0.5){
			if(i < 4) color.rgb = vec3(0.0);
			else color.rgb = vec3(0.5);
			break;
		}
	}
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/sunmoon.glsl"

#ifdef OUTLINE_ENABLED
#include "/lib/util/outlineOffset.glsl"
#include "/lib/util/outlineDepth.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/post/outline.glsl"
#endif

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
#include "/lib/util/encode.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/materialDeferred.glsl"
#include "/lib/reflections/roughReflections.glsl"
#endif

#ifdef END
vec3 GetEndSkyColor(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0);
	worldPos.xyz /= worldPos.w;

	worldPos = normalize(worldPos);

	vec3 sky = vec3(0.0);
	vec3 absWorldPos = abs(worldPos.xyz);
	float maxViewDir = absWorldPos.x;
	sky = vec3(worldPos.yz, 0.0);
	if (absWorldPos.y > maxViewDir) {
		maxViewDir = absWorldPos.y;
		sky = vec3(worldPos.xz, 0.0);
	}
	if (absWorldPos.z > maxViewDir) {
		maxViewDir = absWorldPos.z;
		sky = vec3(worldPos.xy, 0.0);
	}
	vec2 skyUV = sky.xy * 2.0;
	skyUV = (floor(skyUV * 512.0) + 0.5) / 512.0;
	float noise = texture2D(noisetex, skyUV).b;
	sky = vec3(1.0) * pow(noise * 0.3 + 0.35, 2.0);
	sky *= sky;
	sky *= endCol.rgb * 0.03;
	return sky;
}
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord);
	float z = texture2D(depthtex0, texCoord).r;
	float rawZ = z;
	
	#ifdef DISTANT_HORIZONS
	float dhZ = texture2D(dhDepthTex0, texCoord).r;
	#endif

	float dither = Bayer8(gl_FragCoord.xy);

	#if ALPHA_BLEND == 0
	bool isSky = z == 1.0;
	#ifdef DISTANT_HORIZONS
	isSky = isSky && (dhZ == 1.0);
	#endif

	if (isSky) color.rgb = max(color.rgb - dither / vec3(128.0), vec3(0.0));
	color.rgb *= color.rgb;
	#endif
	
	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#ifdef OUTLINE_ENABLED
	vec4 outerOutline = vec4(0.0), innerOutline = vec4(0.0);
	float outlineLinZ = 0.0;
	Outline(color.rgb, viewPos.xyz, false, outerOutline, innerOutline, outlineLinZ);

	color.rgb = mix(color.rgb, innerOutline.rgb, innerOutline.a);
	#endif

	if (z < 1.0) {
		#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
		float smoothness = 0.0, skyOcclusion = 0.0;
		vec3 normal = vec3(0.0), fresnel3 = vec3(0.0);

		GetMaterials(smoothness, skyOcclusion, normal, fresnel3, texCoord);

		if (smoothness > 0.0) {
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);
			
			float ssrMask = clamp(length(fresnel3) * 400.0 - 1.0, 0.0, 1.0);
			if(ssrMask > 0.0) reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness);
			reflection.a *= ssrMask;

			if (reflection.a < 1.0) {
				#ifdef OVERWORLD
				vec3 skyRefPos = reflect(normalize(viewPos.xyz), normal);
				skyReflection = GetSkyColor(skyRefPos, true);
				
				#ifdef REFLECTION_ROUGH
				float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
				#else
				float cloudMixRate = 1.0;
				#endif

				#if AURORA > 0
				skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12) * cloudMixRate;
				#endif

				#if CLOUDS == 1
				vec4 cloud = DrawCloudSkybox(skyRefPos * 100.0, 1.0, dither, lightCol, ambientCol, false);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
				#endif
				#if CLOUDS == 2
				vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0);
				worldPos.xyz /= worldPos.w;

				vec3 cameraPos = GetReflectedCameraPos(worldPos.xyz, normal);
				float cloudViewLength = 0.0;

				vec4 cloud = DrawCloudVolumetric(skyRefPos * 8192.0, cameraPos, 1.0, dither, lightCol, ambientCol, cloudViewLength, true);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
				#endif

				float NoU = clamp(dot(normal, upVec), -1.0, 1.0);
				float NoE = clamp(dot(normal, eastVec), -1.0, 1.0);
				float vanillaDiffuse = (0.25 * NoU + 0.75) +
									   (0.5 - abs(NoE)) * (1.0 - abs(NoU)) * 0.1;
				vanillaDiffuse *= vanillaDiffuse;

				#ifdef CLASSIC_EXPOSURE
				skyReflection *= 4.0 - 3.0 * eBS;
				#endif

				skyReflection = mix(vanillaDiffuse * minLightCol, skyReflection, skyOcclusion);
				#endif
				#ifdef NETHER
				skyReflection = netherCol.rgb * 0.04;
				#endif
				#ifdef END
				skyReflection = endCol.rgb * 0.025;
				#endif
			}

			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
			
			color.rgb += reflection.rgb * fresnel3;
		}
		#endif

		#ifdef AO
		color.rgb *= GetAmbientOcclusion(z);
		#endif

		Fog(color.rgb, viewPos.xyz);
	
	#ifdef DISTANT_HORIZONS
	} else if (dhZ < 1.0) {
		z = 1.0 - 1e-5;
		
		vec4 dhScreenPos = vec4(texCoord, dhZ, 1.0);
		viewPos = dhProjectionInverse * (dhScreenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		#ifdef AO
		color.rgb *= GetDHAmbientOcclusion(dhZ);
		#endif
		
		Fog(color.rgb, viewPos.xyz);
	#endif
	} else {
		#if defined OVERWORLD && defined SKY_DEFERRED
		color.rgb += GetSkyColor(viewPos.xyz, false);
	
		#ifdef SHADER_SUN_MOON
		vec3 lightMA = mix(lightMorning, lightEvening, mefade);
		vec3 sunColor = mix(lightMA, sqrt(lightDay * lightMA * LIGHT_DI), timeBrightness);
	    vec3 moonColor = lightNight * 1.25;

		ShaderSunMoon(color.rgb, viewPos.xyz, sunColor, moonColor);
		#endif

		#ifdef STARS
		if (moonVisibility > 0.0) DrawStars(color.rgb, viewPos.xyz);
		#endif

		#if AURORA > 0
		color.rgb += DrawAurora(viewPos.xyz, dither, 24);
		#endif

		SunGlare(color.rgb, viewPos.xyz, lightCol);

		color.rgb *= 1.0 + nightVision;
		#ifdef CLASSIC_EXPOSURE
		color.rgb *= 4.0 - 3.0 * eBS;
		#endif
		#endif
		#ifdef NETHER
		color.rgb = netherCol.rgb * 0.0425;
		#endif
		#ifdef END
		#ifdef SHADER_END_SKY
		color.rgb = GetEndSkyColor(viewPos.xyz);
		#endif

		#ifndef LIGHT_SHAFT
		float VoL = dot(normalize(viewPos.xyz), lightVec);
		VoL = pow(VoL * 0.5 + 0.5, 16.0) * 0.75 + 0.25;
		color.rgb += endCol.rgb * 0.04 * VoL;
		#endif
		#endif

		if (isEyeInWater > 1) {
			color.rgb = denseFogColor[isEyeInWater - 2];
		}

		if (blindFactor > 0.0 || darknessFactor > 0.0) color.rgb *= 1.0 - max(blindFactor, darknessFactor);
	}

	vec4 cloud = vec4(0.0);
	float cloudDither = BayerCloud8(gl_FragCoord.xy);

	float cloudMaxDistance = 2.0 * far;
	#ifdef DISTANT_HORIZONS
	cloudMaxDistance = max(cloudMaxDistance, dhFarPlane);
	#endif
	float cloudViewLength = cloudMaxDistance;
	
	float cloudSampleZ = z;
	#ifdef OUTLINE_OUTER
	DepthOutline(cloudSampleZ, depthtex0);
	#ifdef DISTANT_HORIZONS
	DHDepthOutline(cloudSampleZ, dhDepthTex0);
	#endif
	#endif

	#ifdef OVERWORLD
	#if CLOUDS == 1
	cloud = DrawCloudSkybox(viewPos.xyz, cloudSampleZ, cloudDither, lightCol, ambientCol, false);
	#endif

	#if CLOUDS == 2
	vec4 cloudViewPos = viewPos;
	#ifdef OUTLINE_OUTER
	cloudViewPos.xyz = GetOutlinedViewPos(outlineLinZ);
	#endif

	cloud = DrawCloudVolumetric(cloudViewPos.xyz, cameraPosition, cloudSampleZ, cloudDither, lightCol, ambientCol, cloudViewLength, false);
	#endif

	if (isEyeInWater > 1) cloud.a = 0.0;

	#ifndef LIGHT_SHAFT
	SunGlare(cloud.rgb, viewPos.xyz, lightCol);
	#endif
	
	cloud.rgb *= 1.0 - max(blindFactor, darknessFactor);

	color.rgb = mix(color.rgb, cloud.rgb, cloud.a);
	#endif
	cloudViewLength /= cloudMaxDistance;

	#ifdef OUTLINE_ENABLED
	outerOutline.rgb = mix(outerOutline.rgb, cloud.rgb, cloud.a);
	color.rgb = mix(color.rgb, outerOutline.rgb, outerOutline.a);
	#endif

	#if MC_VERSION >= 10900 && !defined IS_IRIS
	float isGlowing = texture2D(colortex3, texCoord).b;
	if (isGlowing > 0.5) GlowOutline(color.rgb);
	#endif

	vec3 reflectionColor = pow(color.rgb, vec3(0.125)) * 0.5;

	#if ALPHA_BLEND == 0
	color.rgb = sqrt(max(color.rgb, vec3(0.0)));
	#endif

	float reflectionMask = float(z < 1.0);
	#ifdef DISTANT_HORIZONS
	reflectionMask = max(reflectionMask, float(dhZ < 1.0));
	#endif
    
    /*DRAWBUFFERS:04 */
    gl_FragData[0] = color;
	gl_FragData[1] = vec4(cloudViewLength, 0.0, 0.0, 1.0);

	#if !defined REFLECTION_PREVIOUS && REFRACTION == 0
	/*DRAWBUFFERS:045*/
	gl_FragData[2] = vec4(reflectionColor, reflectionMask);
	#elif defined REFLECTION_PREVIOUS && REFRACTION > 0
	/*DRAWBUFFERS:046*/
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	#elif !defined REFLECTION_PREVIOUS && REFRACTION > 0
	/*DRAWBUFFERS:0456*/
	gl_FragData[2] = vec4(reflectionColor, reflectionMask);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec, eastVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);
}

#endif
