vec3 GetSubsurfaceShadow(vec3 worldPos, float subsurface, float skylight) {
    return vec3(0.0);
}

vec3 GetShadow(vec3 worldPos, vec3 normal, float NoL, float subsurface, float skylight) {
    #ifdef OVERWORLD
    float skylightShadow = smoothstep(SHADOW_SKY_FALLOFF, 1.0, skylight);
    skylightShadow *= skylightShadow;

    return vec3(skylightShadow);
    #else
    return vec3(1.0);
    #endif
}

float GetCloudShadow(vec3 worldPos) {
	vec2 wind = vec2(
		time * CLOUD_SPEED * 0.0005,
		sin(time * CLOUD_SPEED * 0.001) * 0.005
	) * 0.667;

    vec3 coveragePos = worldPos;
    worldPos += cameraPosition;

    vec3 worldLightVec = (gbufferModelViewInverse * vec4(lightVec, 0.0)).xyz;

    #if CLOUD_HEIGHT == -1
	#ifdef IS_IRIS
	float cloudLowerY = cloudHeight;
	#else
	float cloudLowerY = 192.0;
	#endif
	#else
	float cloudLowerY = float(CLOUD_HEIGHT);
	#endif

    worldPos.xz += worldLightVec.xz / worldLightVec.y * max(cloudLowerY - worldPos.y, 0.0);
    coveragePos.xz += worldLightVec.xz / worldLightVec.y * -coveragePos.y;

    float scaledThickness = CLOUD_THICKNESS * CLOUD_SCALE;
    float cloudFadeOut = 1.0 - clamp((worldPos.y - cloudLowerY) / scaledThickness, 0.0, 1.0);
    float coverageFadeOut = 1.0 - clamp((cameraPosition.y - cloudLowerY) / scaledThickness, 0.0, 1.0);

    vec2 coord = worldPos.xz / CLOUD_SCALE;

	#ifdef CLOUD_REVEAL
    float sunCoverageSize = CLOUD_SCALE * 3.0 / worldLightVec.y;
    float sunCoverage = max(1.0 - length(coveragePos.xz) / sunCoverageSize, 0.0) * coverageFadeOut;
    #else
    float sunCoverage = 0.0;
    #endif

	coord *= 0.004 * CLOUD_STRETCH;

	#if CLOUD_BASE_INTERNAL == 0
    coord = coord * 0.25 + wind;
	float noiseBase = texture2D(noisetex, coord).r;

	float noise = mix(noiseBase, 1.0, 0.33 * rainStrength) * 21.0;
	noise = max(noise - (sunCoverage * 3.0 + CLOUD_AMOUNT), 0.0);
	#elif CLOUD_BASE_INTERNAL == 1
    coord = coord * 0.25 + wind * 2.0;

	float noiseBase = texture2D(noisetex, coord).g;
	noiseBase = pow(1.0 - noiseBase, 2.0) * 0.5 + 0.25;

	float noise = mix(noiseBase, 1.0, 0.33 * rainStrength) * 21.0;
	noise = max(noise - (sunCoverage * 3.0 + CLOUD_AMOUNT), 0.0);
    #else
    coord = coord * 0.125 + wind * 0.5;

	float noiseRes = 512.0;

	coord.xy = coord.xy * noiseRes - 0.5;

	vec2 flr = floor(coord.xy);
	vec2 frc = coord.xy - flr;

	frc = clamp(frc * 2.0 - 0.5, vec2(0.0), vec2(1.0));
	frc = frc * frc * (3.0 - 2.0 * frc);

	coord.xy = (flr + frc + 0.5) / noiseRes;

	float noiseBase = texture2D(noisetex, coord).a;
	noiseBase = (1.0 - noiseBase) * 4.0;

    float noise = max(noiseBase * 2.0, 0.0);
	#endif

	noise *= CLOUD_DENSITY * 0.125;
	noise *= (1.0 - 0.75 * rainStrength);
	noise = noise / sqrt(noise * noise + 0.5);
    noise *= cloudFadeOut;

	return 1.0 - noise * CLOUD_OPACITY * 0.85;
}