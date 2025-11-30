#if defined OVERWORLD || defined END
#include "/lib/lighting/shadows.glsl"
#endif

void GetLighting(inout vec3 albedo, out vec3 shadow, vec3 viewPos, vec3 worldPos, vec3 normal,
vec2 lightmap, float smoothLighting, float NoL, float vanillaDiffuse,
float parallaxShadow, float emission, float subsurface, float basicSubsurface) {
    #if EMISSIVE == 0 || (!defined ADVANCED_MATERIALS && EMISSIVE == 1)
    emission = 0.0;
    #endif

    #ifndef SSS
    subsurface = 0.0;
    #endif

    #ifndef BASIC_SSS
    basicSubsurface = 0.0;
    #endif

    float skylightSqr = lightmap.y * lightmap.y;

    #if defined OVERWORLD || defined END
    shadow = GetShadow(worldPos, normal, NoL, basicSubsurface, lightmap.y);

    #ifdef SHADOW_CLOUD
    float cloudShadow = GetCloudShadow(worldPos);
    shadow *= cloudShadow;
    #endif

    float scattering = 0.0;
    if (basicSubsurface > 0.0){
        float VoL = clamp(dot(normalize(viewPos.xyz), lightVec) * 0.5 + 0.5, 0.0, 1.0);
        scattering = pow(VoL, 16.0) * (1.0 - rainStrength) * basicSubsurface * shadowFade;
        NoL = mix(NoL, 1.0, sqrt(basicSubsurface) * 0.7);
        NoL = mix(NoL, 1.0, scattering);
    }

    vec3 fullShadow = vec3(shadow);
    #ifdef OVERWORLD
    float timeBrightnessAbs = abs(sin(timeAngle * 6.28318530718));
    fullShadow *= 0.25 + 0.5 * (1.0 - (1.0 - timeBrightnessAbs) * (1.0 - timeBrightnessAbs));
    fullShadow *= mix(pow(vanillaDiffuse, 1.0 + timeBrightnessAbs), 1.0, basicSubsurface * 0.4);
    #else
    fullShadow *= 0.75;
    #endif

//    #ifdef ADVANCED_MATERIALS
//    if (subsurface > 0.0){
//        vec3 subsurfaceShadow = GetSubsurfaceShadow(worldPos, subsurface, lightmap.y);
//
//        float VoL = clamp(dot(normalize(viewPos.xyz), lightVec) * 0.5 + 0.5, 0.0, 1.0);
//        float scattering = pow(VoL, 16.0) * (1.0 - rainStrength) * shadowFade;
//
//        vec3 subsurfaceColor = normalize(albedo + 0.00001) * 1.2;
//        subsurfaceColor = mix(subsurfaceColor, vec3(1.0), pow(subsurfaceShadow, vec3(4.0)));
//        subsurfaceColor = mix(subsurfaceColor, vec3(4.0), scattering) * sqrt(subsurface);
//
//        fullShadow = mix(subsurfaceColor * subsurfaceShadow, vec3(1.0), fullShadow);
//    }
//    #endif

    #ifdef OVERWORLD
    float shadowMult = (1.0 - 0.95 * rainStrength) * shadowFade;
    vec3 sceneLighting = mix(ambientCol * lightmap.y, lightCol, fullShadow * shadowMult);
    sceneLighting *= skylightSqr * (1.0 + scattering * shadow);

    #ifdef CLASSIC_EXPOSURE
    sceneLighting *= 4.0 - 3.0 * eBS;
    #endif
    #endif

    #ifdef END
    vec3 sceneLighting = endCol.rgb * (0.04 * fullShadow + 0.015);
    #endif

    #else
    vec3 sceneLighting = netherColSqrt.rgb * 0.07;
    #endif

    float newLightmap  = pow(lightmap.x, 10.0) * 1.6 + lightmap.x * 0.6;
    vec3 blockLighting = blocklightCol * newLightmap * newLightmap;

    vec3 minLighting = minLightCol * (1.0 - skylightSqr);

    #ifdef TOON_LIGHTMAP
    minLighting *= floor(smoothLighting * 8.0 + 1.001) / 4.0;
    smoothLighting = 1.0;
    #endif

    vec3 albedoNormalized = normalize(albedo.rgb + 0.00001);
    emission = pow(emission, max(EMISSIVE_CURVE, 1.0));
    vec3 emissiveLighting = mix(albedoNormalized, vec3(1.0), emission * 0.5);
    emissiveLighting *= emission * EMISSIVE_INTENSITY;

    float lightFlatten = clamp(1.0 - pow(1.0 - emission, 128.0), 0.0, 1.0);
    vanillaDiffuse = mix(vanillaDiffuse, 1.0, lightFlatten);
    smoothLighting = mix(smoothLighting, 1.0, lightFlatten);

    float nightVisionLighting = nightVision * 0.25;

    #ifdef ALBEDO_BALANCING
    float albedoBrightness = max(max(albedo.r, albedo.g), albedo.b);
    albedo.rgb /= 1.0 + albedoBrightness * 0.25 * (1.0 - lightFlatten);
    #endif

    //albedo = vec3(0.5);
    albedo *= max(sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting, vec3(0.0));
    albedo *= vanillaDiffuse * smoothLighting * smoothLighting;
    // albedo = blocklightCol * 0.25;

    #ifdef DESATURATION
    #ifdef OVERWORLD
    float desatAmount = 1.0 - sqrt(max(sqrt(length(fullShadow / 3.0)) * lightmap.y, lightmap.y)) *
    sunVisibility * (1.0 - rainStrength * 0.7);
    desatAmount*= smoothstep(0.25, 1.0, (1.0 - lightmap.x) * (1.0 - lightmap.x)) * (1.0 - lightFlatten);
    desatAmount = 1.0 - desatAmount;

    vec3 desatNight   = normalize(lightNight * lightNight + 0.000001);
    vec3 desatWeather = normalize(weatherCol.rgb * weatherCol.rgb + 0.000001);

    float desatNWMix  = (1.0 - sunVisibility) * (1.0 - rainStrength);

    vec3 desatColor = mix(desatWeather, desatNight, desatNWMix);
    desatColor = mix(vec3(0.4), desatColor, sqrt(lightmap.y)) * 1.7;
    #endif

    #ifdef NETHER
    float desatAmount = 1.0 - smoothstep(0.25, 1.0, (1.0 - lightmap.x) * (1.0 - lightmap.x)) * (1.0 - lightFlatten);

    vec3 desatColor = normalize(netherColSqrt.rgb + 0.000001) * 1.7;
    #endif

    #ifdef END
    float desatAmount = 1.0 - smoothstep(0.25, 1.0, (1.0 - lightmap.x) * (1.0 - lightmap.x)) * (1.0 - lightFlatten);

    vec3 desatColor = normalize(endCol.rgb + 0.000001) * 1.7;
    #endif

    vec3 desatAlbedo = mix(albedo, dot(albedo,vec3(0.299, 0.587, 0.114)) * desatColor, 1.0 - DESATURATION_FACTOR * 0.4);

    albedo = mix(desatAlbedo, albedo, desatAmount);
    #endif
}