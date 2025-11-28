void DepthOutline(inout float z, sampler2D depthtex) {
	float ph = ceil(viewHeight / 1440.0) / viewHeight;
	float pw = ph / aspectRatio;

    int sampleCount = viewHeight >= 720.0 ? 12 : 4;
	
    #ifdef RETRO_FILTER
    ph = RETRO_FILTER_SIZE / viewHeight;
    pw = ph / aspectRatio;
    sampleCount = 4;
    #endif

	for (int i = 0; i < sampleCount; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
		for (int j = 0; j < 2; j++) {
			z = min(z, texture2D(depthtex, texCoord + offset).r);
			offset = -offset;
		}
	}
}

#ifdef LOD_RENDERER
void LodDepthOutline(inout float z, sampler2D depthtex) {
	if (z < 1.0) return;

	float ph = ceil(viewHeight / 1440.0) / viewHeight;
	float pw = ph / aspectRatio;

    int sampleCount = viewHeight >= 720.0 ? 12 : 4;
	
    #ifdef RETRO_FILTER
    ph = RETRO_FILTER_SIZE / viewHeight;
    pw = ph / aspectRatio;
    sampleCount = 4;
    #endif

	for (int i = 0; i < sampleCount; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
		for (int j = 0; j < 2; j++) {
			float sampleZ = texture2D(depthtex, texCoord + offset).r;
			if (sampleZ < 1.0) z = 1.0 - 1e-5;
			offset = -offset;
		}
	}
}
#endif