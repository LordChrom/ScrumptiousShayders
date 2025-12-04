/*
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/

#define VOXY_PATCH

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
//
//#ifdef ADVANCED_MATERIALS
//vec2 dcdx = dFdx(texCoord);
//vec2 dcdy = dFdy(texCoord);
//#endif



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

    #ifdef GLOWING_ORES
    float emissive = float(blockId<=16100 && 15003<=blockId);
    #else
    float emissive = float(blockId<=15900 && 15003<=blockId);
    #endif
    float foliage  = float(blockId==10000);
    float leaves   = float(blockId==10500);
    float lava     = float(blockId==15302);
    float candle = 0;

    float metalness       = 0.0;
    float emission        = (emissive + candle + lava);
    float subsurface      = 0.0;
    float basicSubsurface = (foliage + candle) * 0.5 + leaves;
    vec3 baseReflectance  = vec3(0.04);


    vec4 color = parameters.tinting;

    if(leaves>0){
        color.rgb *= 1.225;
    }

    vec4 albedo = parameters.sampledColour * vec4(color.rgb, 1.0);

//    albedo*= uint2vec4RGBA(interData.z).yzwx;
//albedo *= uint2vec4RGBA(interData.y);

//    albedo = (albedo * uint2vec4RGBA(interData.y)) + vec4(0,0,0,float(interData.w&0xFFu)/255);



    //DEFINITELY move this normal stuff to fragment shaders once voxy lets us do that.
    //or figure out a way to circumvent this transformation
    //Also fix translucent if this is fixed
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

    vec2 lightmap = clamp(parameters.lightMap,vec2(0),vec2(1));

    vec3 hsv = RGB2HSV(albedo.rgb);
    emission *= GetHardcodedEmission(albedo.rgb, hsv);

    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    #ifdef TAA
    vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
    #else
    vec3 viewPos = ToNDC(screenPos);
    #endif
    vec3 worldPos = mat3(vxModelViewInv) * viewPos + vxModelViewInv[3].xyz;

    float dither = Bayer8(gl_FragCoord.xy);

    vec3 noisePos = (worldPos + cameraPosition) * 4.0;
    float albedoLuma = GetLuminance(albedo.rgb);
    float noiseAmount = (1.0 - albedoLuma * albedoLuma) * 0.05;
    float albedoNoise = GetBlueNoise3D(noisePos, normal);
    albedo.rgb = clamp(albedo.rgb + albedoNoise * noiseAmount, vec3(0.0), vec3(1.0));

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

    #ifdef MULTICOLORED_BLOCKLIGHT
//        lightAlbedo *= GetMCBLLegacyMask(worldPos);
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

    #ifndef NORMAL_PLANTS
    if (foliage > 0.5) vanillaDiffuse *= 1.8;
    #endif

    if (leaves > 0.5) {
//            float halfNoL = dot(newNormal, lightVec) * 0.5 + 0.5;
//            basicSubsurface *= halfNoL * step(length(albedo.rgb), 1.7);
//            basicSubsurface*=2;
//            albedo.rgb*=1.5;
    }




    float parallaxShadow=1.0;


    #ifdef ADVANCED_MATERIALS
//        vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
//        albedo.rgb *= ao * ao;
//
    #ifdef REFLECTION_SPECULAR
//        albedo.rgb *= 1.0 - metalness * smoothness;
    #endif

//        float doParallax = 0.0;
    #ifdef SELF_SHADOW
//        float parallaxNoL = dot(outNormal, lightVec);
    #ifdef OVERWORLD
//        doParallax = float(lightmap.y > 0.0 && parallaxNoL > 0.0);
    #endif
    #ifdef END
//        doParallax = float(parallaxNoL > 0.0);
    #endif
//        if (doParallax > 0.5 && skipParallax < 0.5) {
//            parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
//            tbnMatrix);
//        }
    #endif
//
    #ifdef DIRECTIONAL_LIGHTMAP
//        mat3 lightmapTBN = GetLightmapTBN(viewPos);
//        lightmap.x = DirectionalLightmap(lightmap.x, lihgtmap.x, outNormal, lightmapTBN);
//        lightmap.y = DirectionalLightmap(lightmap.y, lihgtmap.y, outNormal, lightmapTBN);
    #endif
    #endif






    vec3 shadow = vec3(0.0);


    GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, color.a, NoL,
        vanillaDiffuse, parallaxShadow, emission, subsurface, basicSubsurface);

//        #ifdef ADVANCED_MATERIALS
//        float puddles = 0.0;
//
//        skyOcclusion = lightmap.y;
//
//        baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
//        float fresnel = pow(clamp(1.0 + dot(outNormal, normalize(viewPos.xyz)), 0.0, 1.0), 5.0);
//
//        fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
//        #if MATERIAL_FORMAT == 1
//        if (f0 >= 0.9 && f0 < 1.0) {
//            baseReflectance = GetMetalCol(f0);
//            fresnel3 = ComplexFresnel(pow(fresnel, 0.2), f0);
//            #ifdef ALBEDO_METAL
//            fresnel3 *= rawAlbedo;
//            #endif
//        }
//        #endif
//
//        float aoSquared = ao * ao;
//        shadow *= aoSquared; fresnel3 *= aoSquared;
//        albedo.rgb = albedo.rgb * (1.0 - fresnel3 * smoothness * smoothness * (1.0 - metalness));
//        #endif

    #if ALPHA_BLEND == 0
    albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
    #endif


    /* DRAWBUFFERS:0 */
    gbufferData0 = albedo;
}

#endif