// Panorama delle rovine (training 0.5): immagine equirettangolare a distanza infinita, quindi
// con disparità nulla. Il centro dell'immagine sta davanti (-Z), la destra a destra.
shader_type sky;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float brightness = 1.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float u = atan(d.x, -d.z) / (2.0 * PI) + 0.5;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	COLOR = texture(panorama, vec2(u, v)).rgb * brightness;
}
