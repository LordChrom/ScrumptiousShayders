/*
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/

#define VOXY_PATCH
#define texture2D texture

//Settings//
#include "/lib/settings.glsl"
//
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH
#undef MULTICOLORED_BLOCKLIGHT

#define gbufferModelView            lodModelView
#define gbufferModelViewInverse     lodModelViewInverse
#define gbufferProjection           lodProjection
#define gbufferProjectionInverse    lodProjectionInverse
#define gbufferPreviousModelView    lodPreviousModelView
#define gbufferPreviousProjection   lodPreviousProjection

////Common Variables//
layout(location = 0) out vec4 gbufferData0;
#ifdef MCBL_SS
layout(location = 1) out vec4 gbufferData1;
#endif

const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
float ang1 = fract(timeAngle - 0.25);
float ang = (ang1 + (cos(ang1 * 3.14159265358979) * -0.5 + 0.5 - ang1) / 3.0) * 6.28318530717959;
vec3 sunVec = normalize((vxModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
vec3 upVec = normalize(vxModelView[1].xyz);
vec3 eastVec = normalize(vxModelView[0].xyz);

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

float dayPower = sunVisibility;

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif


vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);


////Common Functions//
float GetLuminance(vec3 color) {
    return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetBlueNoise3D(vec3 pos, vec3 normal) {
    pos = (floor(pos + 0.01) + 0.5) / 512.0;

    vec3 worldNormal = (vxModelViewInv * vec4(normal, 0.0)).xyz;
    vec3 noise3D = vec3(
    texture2D(noisetex, pos.yz).b,
    texture2D(noisetex, pos.xz).b,
    texture2D(noisetex, pos.xy).b
    );

    float noiseX = noise3D.x * abs(worldNormal.x);
    float noiseY = noise3D.y * abs(worldNormal.y);
    float noiseZ = noise3D.z * abs(worldNormal.z);
    float noise = noiseX + noiseY + noiseZ;

    return noise - 0.5;
}

////Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/hardcodedEmission.glsl"

//#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/lighting/lodLighting.glsl"

#ifdef MCBL_SS
#include "/lib/util/voxelMapHelper.glsl"
#include "/lib/lighting/coloredBlocklight.glsl"
#endif

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

//struct VoxyFragmentParameters {
//    vec4 sampledColour;
//    vec2 tile;
//    vec2 uv;
//    uint face;
//    uint modelId;
//    vec2 lightMap;
//    vec4 tinting;
//    uint customId;//Same as iris's modelId
//};


//TODO: Nether needs work

//Program//
void voxy_emitFragment(VoxyFragmentParameters parameters) {
    uint blockId = parameters.customId;
    vec4 color = parameters.tinting;



    float leaves   = float(blockId==10500);

    if(parameters.sampledColour.a<0.001){

        #if VOXY_FAKE_LEAF_SHADOW == 1 || VOXY_FAKE_LEAF_SHADOW == 3
        if(leaves>0){
            //        float dither = Bayer8(uv);
            float dither = Bayer4(gl_FragCoord.xy+gl_FragCoord.z);

            float ditherDarkness = 0.5;

            if (parameters.face==1){
                ditherDarkness=0.7;
            }

            if (dither<ditherDarkness){
                gbufferData0=vec4(color.rgb*0.1,0);
                return;
            }
        }
        #endif
        discard;
    }

    #ifdef GLOWING_ORES
    float emissive = float(blockId<=16100 && 15003<=blockId);
    #else
    float emissive = float(blockId<=15900 && 15003<=blockId);
    #endif
    float foliage  = float(blockId==10000);
    float lava     = float(blockId==15302);
    float candle = 0;

    float portal = float(blockId==20310);

    float metalness       = 0.0;
    float emission        = (emissive + candle + lava + portal);
    float subsurface      = 0.0;
    float basicSubsurface = (foliage + candle+leaves) * 0.5 + leaves;
    vec3 baseReflectance  = vec3(0.04);

    vec2 lightmap = clamp(parameters.lightMap,vec2(0),vec2(1));



    if(leaves>0){
        color.rgb*-1.225/1.08;

        #if VOXY_FAKE_LEAF_SHADOW == 2 || VOXY_FAKE_LEAF_SHADOW == 3
        if((uint(parameters.face)>>1u!=0u) && lightmap.y>=0.95){
            color.rgb*=0.8;
        }
        #endif
    }

    vec4 albedo = parameters.sampledColour * vec4(color.rgb, 1.0);


    //for some reason its just approximately that much darker in the LODs.
    //probably worth diving into the cause of this, but seeing as that affects like every shader im guessing its not BSL's fault
    #ifdef OVERWORLD
    albedo.rgb*=1.08;
    #endif

    //vertex shading :/
    vec3 normal;
    switch(uint(parameters.face)>>1u){
        case 0u:
        normal = vxModelView[1].xyz;
        break;
        case 1u:
        normal = vxModelView[2].xyz;
        break;
        case 2u:
        normal = vxModelView[0].xyz;
        break;
    }
    if((parameters.face&1)==0) normal=-normal;
//      normal = vxModelView[((uint(parameters.face)>>1u)+1u)%3u].xyz;

    vec3 newNormal = normal;


    vec3 hsv = RGB2HSV(albedo.rgb);
    emission *= GetHardcodedEmission(albedo.rgb, hsv);

    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    #ifdef TAA
    vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
    #else
    vec3 viewPos = ToNDC(screenPos);
    #endif
    vec3 worldPos = mat3(vxModelViewInv) * viewPos + vxModelViewInv[3].xyz;


    #ifdef TOON_LIGHTMAP
    lightmap = floor(lightmap * 14.999) / 14.0;
    lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
    #endif

    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    #ifdef EMISSIVE_RECOLOR
    float ec = GetLuminance(albedo.rgb) * 1.7;
    if (recolor > 0.5) {
        albedo.rgb = blocklightCol * pow(ec, 1.5) / (BLOCKLIGHT_I * BLOCKLIGHT_I);
        albedo.rgb /= 0.7 * albedo.rgb + 0.7;
    }
    if (lava > 0.5) {
        albedo.rgb = pow(blocklightCol * ec / BLOCKLIGHT_I, vec3(2.0));
        albedo.rgb /= 0.5 * albedo.rgb + 0.5;
    }
    #endif

    #ifdef MCBL_SS
    vec3 lightAlbedo = albedo.rgb + 0.00001;
    if (lava > 0.5) {
        lightAlbedo = pow(lightAlbedo, vec3(0.25));
    }
    lightAlbedo = sqrt(normalize(lightAlbedo) * emission);
//
//    if(emission>0.5)
//        lightAlbedo=vec3(0.5,0,0);
//    else
//        lightAlbedo=vec3(0);
//
//    if(portal>0){
//        lightAlbedo=vec3(1,0,1);
//    }

    #ifdef MULTICOLORED_BLOCKLIGHT
        lightAlbedo *= GetMCBLLegacyMask(worldPos);
    #endif
    #endif

    #ifdef WHITE_WORLD
    albedo.rgb = vec3(0.35);
    #endif

    vec3 outNormal = newNormal;

    #if HALF_LAMBERT_INTERNAL == 0
    float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);
    #else
    float NoL = clamp(dot(newNormal, lightVec) * 0.5 + 0.5, 0.0, 1.0);
    NoL *= NoL;
    #endif


    float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
    float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
    float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
    vanillaDiffuse*= vanillaDiffuse;


    #if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
    blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, newNormal);
    #endif


    float parallaxShadow=1.0;
    vec3 shadow = vec3(0.0);


    GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, color.a, NoL,
        vanillaDiffuse, parallaxShadow, emission, subsurface, basicSubsurface);


    #if ALPHA_BLEND == 0
    albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
    #endif


    /* DRAWBUFFERS:0 */
    gbufferData0 = albedo;

    #ifdef MCBL_SS
    /* DRAWBUFFERS:08 */
    gbufferData1 = vec4(lightAlbedo, 1.0);
//    gbufferData1 = vec4(0,0.01,0, 100.0);
    #endif
}

#endif