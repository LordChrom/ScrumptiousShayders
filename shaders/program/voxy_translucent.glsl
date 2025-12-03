/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/
#define VOXY_PATCH

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH
#if VOXY_TRANSLUCENTS < 3
#undef ADVANCED_MATERIALS
#undef REFLECTION_TRANSLUCENT
#undef REFLECTION_SPECULAR
#undef DIRECTIONAL_LIGHTMAP

#define REFLECTIONS 0
#define WATER_NORMALS_INTERNAL 0
#endif

#if VOXY_TRANSLUCENTS >= 2

#define gbufferModelView            lodModelView
#define gbufferModelViewInverse     lodModelViewInverse
#define gbufferProjection           lodProjection
#define gbufferProjectionInverse    lodProjectionInverse

//Varyings//
//varying vec3 binormal, tangent;

//Common Variables//
layout(location = 0) out vec4 gbuffer_data;

const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
float ang1 = fract(timeAngle - 0.25);
float ang = (ang1 + (cos(ang1 * 3.14159265358979) * -0.5 + 0.5 - ang1) / 3.0) * 6.28318530717959;
vec3 sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
vec3 upVec = normalize(gbufferModelView[1].xyz);
vec3 eastVec = normalize(gbufferModelView[0].xyz);

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

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
//
vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

////Common Functions//
float GetLuminance(vec3 color) {
    return dot(color,vec3(0.299, 0.587, 0.114));
}

//these compile, but waving water is kind of a non-starter without voxy vertex shaders

//float GetWaterHeightMap(vec3 worldPos, vec2 offset) {
//    float noise = 0.0, noiseA = 0.0, noiseB = 0.0;
//
//    vec2 wind = vec2(time) * 0.5 * WATER_SPEED;
//
//    worldPos.xz += worldPos.y * 0.2;
//
//    #if WATER_NORMALS_INTERNAL == 1
//    offset /= 256.0;
//    noiseA = texture2D(noisetex, (worldPos.xz - wind) / 256.0 + offset).g;
//    noiseB = texture2D(noisetex, (worldPos.xz + wind) / 48.0 + offset).g;
//    #elif WATER_NORMALS_INTERNAL == 2
//    offset /= 256.0;
//    noiseA = texture2D(noisetex, (worldPos.xz - wind) / 256.0 + offset).r;
//    noiseB = texture2D(noisetex, (worldPos.xz + wind) / 96.0 + offset).r;
//    noiseA *= noiseA; noiseB *= noiseB;
//    #endif
//
//    #if WATER_NORMALS_INTERNAL > 0
//    noise = mix(noiseA, noiseB, WATER_DETAIL);
//    #endif
//
//    return noise * WATER_BUMP;
//}
//
//vec3 GetParallaxWaves(vec3 worldPos, vec3 viewVector, float dist) {
//    vec3 parallaxPos = worldPos;
//
//    for(int i = 0; i < 4; i++) {
//        float height = -1.25 * GetWaterHeightMap(parallaxPos, vec2(0.0)) + 0.25;
//        parallaxPos.xz += height * viewVector.xy / dist;
//    }
//    return parallaxPos;
//}
//
//vec3 GetWaterNormal(vec3 worldPos, vec3 viewPos, vec3 viewVector, vec3 normal) {
//    vec3 waterPos = worldPos + cameraPosition;
//
//    #if WATER_PIXEL > 0
//    waterPos = floor(waterPos * WATER_PIXEL) / WATER_PIXEL;
//    #endif
//
//    #ifdef WATER_PARALLAX
//    waterPos = GetParallaxWaves(waterPos, viewVector,0);
//    #endif
//
//    float normalOffset = WATER_SHARPNESS;
//
//    float fresnel = pow(clamp(1.0 + dot(normalize(normal), normalize(viewPos)), 0.0, 1.0), 8.0);
//    float normalStrength = 0.35 * (1.0 - fresnel);
//
//    float h1 = GetWaterHeightMap(waterPos, vec2( normalOffset, 0.0));
//    float h2 = GetWaterHeightMap(waterPos, vec2(-normalOffset, 0.0));
//    float h3 = GetWaterHeightMap(waterPos, vec2(0.0,  normalOffset));
//    float h4 = GetWaterHeightMap(waterPos, vec2(0.0, -normalOffset));
//
//    float xDelta = (h2 - h1) / normalOffset;
//    float yDelta = (h4 - h3) / normalOffset;
//
//    vec3 normalMap = vec3(xDelta, yDelta, 1.0 - (xDelta * xDelta + yDelta * yDelta));
//    return normalMap * normalStrength + vec3(0.0, 0.0, 1.0 - normalStrength);
//}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/atmospherics/waterFog.glsl"
//#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/lighting/lodLighting.glsl"

#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/simpleReflections.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/hardcodedEmission.glsl"

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

/*
struct VoxyFragmentParameters {
    vec4 sampledColour;
    vec2 tile;
    vec2 uv;
    uint face;
    uint modelId;
    vec2 lightMap;
    vec4 tinting;
    uint customId; // Same as iris's modelId
};
*/
#endif
//Program//
void voxy_emitFragment(VoxyFragmentParameters parameters) {
    #if VOXY_TRANSLUCENTS == 0
        discard;
    #endif

    vec4 albedo = parameters.sampledColour;
    vec4 color = parameters.tinting;
    albedo*=vec4(color.rgb,1.0);

    #if VOXY_TRANSLUCENTS >= 2
    if(color.a < 0.1) color.a = 1.0;

    uint blockId = parameters.customId;

    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);


    float smoothness = 0.0;
    vec3 lightAlbedo = vec3(0.0);

    vec3 vlAlbedo = vec3(1.0);
    vec3 refraction = vec3(0.0);

    float cloudBlendOpacity = 1.0;

    if (albedo.a > 0.001) {

        vec4 color = parameters.tinting;

        //Convert to vertex shader if possible when voxy lets us. See opaque
        vec3 normal;

        switch(parameters.face>>1){
            case 0:
            normal = vxModelView[1].xyz;
            break;
            case 1:
            normal = vxModelView[2].xyz;
            break;
            case 2:
            normal = vxModelView[0].xyz;
            break;
        }
        if((parameters.face&1)==0) normal=-normal;


        vec3 newNormal = normal;

        vec2 lightmap = clamp(parameters.lightMap,vec2(0),vec2(1));


        float water  = float(blockId==20000);
        float glass = float(blockId<=20200 && 20100<=blockId);
        float portal  = 0; //voxy nether portals opaque, end portals dont render
        float translucent = 0;
//
        float metalness       = 0.0;
        float emission        = portal;
        float subsurface      = 0.0;
        float basicSubsurface = water;
        vec3 baseReflectance  = vec3(0.04);

        //fudge factor for glass
        //doesn't look perfect but looks pretty close
        //the actual albedo and RGB match,
        //so this is definitely compensating for some other discrepancy
        if(glass>0.5){
            albedo.a*=0.4;
            albedo.rgb*=2.5;
        }

        vec3 hsv = RGB2HSV(albedo.rgb);
        emission *= GetHardcodedEmission(albedo.rgb, hsv);

        #ifndef REFLECTION_TRANSLUCENT
        glass = 0.0;
        translucent = 0.0;
        #endif

        #ifdef TAA
        vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
        #else
        vec3 viewPos = ToNDC(screenPos);
        #endif
        vec3 worldPos = mat3(vxModelViewInv) * viewPos + vxModelViewInv[3].xyz;

        float dither = Bayer8(gl_FragCoord.xy);

//  this doesnt save perf in voxy because it already prevents overdraw effectively
//        float viewLength = length(viewPos);
//        float minDist = (dither - DH_OVERDRAW) * 16.0 + far;
//        if (viewLength < minDist) {
//            discard;
//        }
//        #if CLOUDS == 2
//        float cloudMaxDistance = 2.0 * far;
//        #ifdef LOD_RENDERER
//        cloudMaxDistance = max(cloudMaxDistance, lodFarPlane);
//        #endif
//
//        float cloudViewLength = texture2D(gaux1, screenPos.xy).r * cloudMaxDistance;
//
//  this is broken in voxy
//        cloudBlendOpacity = step(viewLength, cloudViewLength);
//        cloudBlendOpacity=1;
//        if (cloudBlendOpacity == 0) {
//                discard;
//        }
//        #endif


        #if WATER_NORMALS_INTERNAL == 1 || WATER_NORMALS_INTERNAL == 2 || defined ADVANCED_MATERIALS
//        vec3 normalMap = vec3(0.0, 0.0, 1.0);
//
//        mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
//        tangent.y, binormal.y, normal.y,
//        tangent.z, binormal.z, normal.z);
        #endif

        #if WATER_NORMALS_INTERNAL == 1 || WATER_NORMALS_INTERNAL == 2
//        if (water > 0.5) {
//            normalMap = GetWaterNormal(worldPos, viewPos, vec3(1),normal);
//            newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
//        }
        #endif

        #ifdef ADVANCED_MATERIALS
        float f0 = 0.0, porosity = 0.5, ao = 1.0, skyOcclusion = 0.0;
//        if (water < 0.5) {
//            GetMaterials(smoothness, metalness, f0, emission, subsurface, porosity, ao, normalMap,
//            newCoord, dcdx, dcdy);

//            if ((normalMap.x > -0.999 || normalMap.y > -0.999) && viewVector == viewVector)
//            newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
//        }
        #endif
//
//
//        #if REFRACTION == 1
//        refraction = vec3((newNormal.xy - normal.xy) * 0.5 + 0.5, float(albedo.a < 0.95) * water);
//        #elif REFRACTION == 2
//        refraction = vec3((newNormal.xy - normal.xy) * 0.5 + 0.5, float(albedo.a < 0.95));
//        #endif

        #ifdef TOON_LIGHTMAP
        lightmap = floor(lmCoord * 14.999) / 14.0;
        lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
        #endif

        albedo.rgb = pow(albedo.rgb, vec3(2.2));

        vlAlbedo = albedo.rgb;

        #ifdef WHITE_WORLD
        albedo.rgb = vec3(0.35);
        #endif

        if (water > 0.5 || ((translucent + glass) > 0.5 && albedo.a < 0.95)) {

            #if WATER_MODE_INTERNAL == 0
            albedo.rgb = waterColor.rgb * waterColor.a / albedo.a;
            #elif WATER_MODE_INTERNAL == 1
            albedo.rgb *= WATER_VI * WATER_VI;
            #elif WATER_MODE_INTERNAL == 2
            float waterLuma = length(albedo.rgb / pow(color.rgb, vec3(2.2)));
            albedo.rgb = waterLuma * waterColor.rgb * waterColor.a;
            #elif WATER_MODE_INTERNAL == 3
            albedo.rgb *= WATER_VI * WATER_VI * 2.0;
            #endif
            #if WATER_ALPHA_MODE_INTERNAL == 0
            albedo.a = waterAlpha;
            #else
            albedo.a = pow(albedo.a, WATER_VA);
            #endif
            vlAlbedo = sqrt(albedo.rgb);
            baseReflectance = vec3(0.02);
        }

        #if WATER_FOG == 1
//        vec3 fogAlbedo = albedo.rgb;
        #endif

        vlAlbedo = mix(vec3(1.0), vlAlbedo, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));

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

        #ifdef ADVANCED_MATERIALS
        vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
        albedo.rgb *= ao;

        #ifdef REFLECTION_SPECULAR
        albedo.rgb *= 1.0 - metalness * smoothness;
        #endif

        #ifdef DIRECTIONAL_LIGHTMAP
        mat3 lightmapTBN = GetLightmapTBN(viewPos);
        lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
        lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
        #endif
        #endif

        vec3 shadow = vec3(0.0);
            GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, 1.0, NoL,
            vanillaDiffuse, 1.0, emission, subsurface, basicSubsurface);


        float fresnel = pow(clamp(1.0 + dot(newNormal, normalize(viewPos)), 0.0, 1.0), 5.0);

        if (water > 0.5 || ((translucent + glass) > 0.5 && albedo.a < 0.95)) {
            #if REFLECTION > 0 && VOXY_TRANSLUCENT_REFLECTIONS > 0 && VOXY_TRANSLUCENTS >= 3
            vec4 reflection = vec4(0.0);
            vec3 skyReflection = vec3(0.0);
            float reflectionMask = 0.0;

            fresnel = fresnel * 0.98 + 0.02;
            fresnel*= max(1.0 - isEyeInWater * 0.5 * water, 0.5);

            #if REFLECTION == 2
            if(parameters.face!=0){
                #if VOXY_TRANSLUCENT_REFLECTIONS == 2
                    reflection = SimpleReflection(viewPos, newNormal, dither, reflectionMask);
                #else
                    reflection = DHReflection(viewPos, newNormal, dither, reflectionMask);
                #endif
            }
            reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));


            #endif


            if (reflection.a < 1.0) {
                #ifdef OVERWORLD
                vec3 skyRefPos = reflect(normalize(viewPos), newNormal);
                skyReflection = GetSkyColor(skyRefPos, true);

                #if AURORA > 0
                skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12);
                #endif

                #if CLOUDS == 1
                vec4 cloud = DrawCloudSkybox(skyRefPos * 100.0, 1.0, dither, lightCol, ambientCol, true);
                skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
                #endif
                #if CLOUDS == 2
                vec3 cameraPos = GetReflectedCameraPos(worldPos, newNormal);
                float cloudViewLength = 0.0;

                vec4 cloud = DrawCloudVolumetric(skyRefPos * 8192.0, cameraPos, 1.0, dither, lightCol, ambientCol, cloudViewLength, true);
                skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
                #endif

                #ifdef CLASSIC_EXPOSURE
                skyReflection *= 4.0 - 3.0 * eBS;
                #endif

                float waterSkyOcclusion = lightmap.y;
                #if REFLECTION_SKY_FALLOFF > 1
                waterSkyOcclusion = clamp(1.0 - (1.0 - waterSkyOcclusion) * REFLECTION_SKY_FALLOFF, 0.0, 1.0);
                #endif
                waterSkyOcclusion *= waterSkyOcclusion;
                skyReflection *= waterSkyOcclusion;
                #endif

                #ifdef NETHER
                skyReflection = netherCol.rgb * 0.04;
                #endif

                #ifdef END
                skyReflection = endCol.rgb * 0.01;
                #endif

                skyReflection *= clamp(1.0 - isEyeInWater, 0.0, 1.0);
            }

            reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));

            #if (defined OVERWORLD || defined END) && SPECULAR_HIGHLIGHT == 2
            vec3 specularColor = GetSpecularColor(lightmap.y, 0.0, vec3(1.0));

                vec3 specular = GetSpecularHighlight(newNormal, viewPos,  0.9, vec3(0.02),
                specularColor, shadow, color.a);
            #if ALPHA_BLEND == 0
            float specularAlpha = pow(mix(albedo.a, 1.0, fresnel), 2.2) * fresnel;
            #else
            float specularAlpha = mix(albedo.a , 1.0, fresnel) * fresnel;
            #endif

                reflection.rgb += specular * (1.0 - reflectionMask) / specularAlpha;
            #endif

            albedo.rgb = mix(albedo.rgb, reflection.rgb, fresnel);
            albedo.a = mix(albedo.a, 1.0, fresnel);

            #endif
        }

        //not really visible even on RD 2
        #if WATER_FOG == 1
//        if((isEyeInWater == 0 && water > 0.5) || (isEyeInWater == 1 && water < 0.5)) {
//            float opaqueDepth = texture2D(vxDepthTexOpaque, screenPos.xy).r;
//            vec3 opaqueScreenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), opaqueDepth);
//            #ifdef TAA
//            vec3 opaqueViewPos = ToNDC(vec3(TAAJitter(opaqueScreenPos.xy, -0.5), opaqueScreenPos.z));
//            #else
//            vec3 opaqueViewPos = ToNDC(opaqueScreenPos);
//            #endif
//
//            vec4 waterFog = GetWaterFog(opaqueViewPos - viewPos.xyz, fogAlbedo);
//            albedo = mix(waterFog, vec4(albedo.rgb, 1.0), albedo.a);
//        }
        #endif

        //broken?
//            Fog(albedo.rgb, viewPos);

        #if ALPHA_BLEND == 0
        albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
        #endif

    }
    albedo.a *= cloudBlendOpacity;
    #endif

    gbuffer_data = albedo;
}

#endif