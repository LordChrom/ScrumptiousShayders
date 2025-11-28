#if (WATER_MODE_INTERNAL == 1 || WATER_MODE_INTERNAL == 3) && SKY_VANILLA_INTERNAL == 0 && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos, vec3 waterAlbedo) {
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-2.0 * fog);
    
    #if WATER_MODE_INTERNAL == 0 || WATER_MODE_INTERNAL == 2
    vec3 waterFogColor = waterColor.rgb * waterColor.a;
    #elif  WATER_MODE_INTERNAL == 1 || WATER_MODE_INTERNAL == 3
    vec3 waterFogColor = fogColor * fogColor * 0.125;
    if (isEyeInWater == 0) waterFogColor = waterAlbedo;
    #endif
    waterFogColor *= WATER_F * WATER_F * (1.0 - max(blindFactor, darknessFactor));

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * eBS * shadowFade * 0.9 + 0.1;
    #endif
    #ifdef NETHER
    vec3 waterFogTint = netherCol.rgb;
    #endif
    #ifdef END
    vec3 waterFogTint = endCol.rgb;
    #endif
    waterFogTint = sqrt(waterFogTint * length(waterFogTint));

    waterFogColor *= waterFogTint;

    return vec4(waterFogColor, fog);
}