shader_type canvas_item;

// 2D 卡通反向外扩描边（§11.4.6 / §5.4）：在精灵透明边缘采样邻居 alpha，
// 仅在不透明像素周围一圈绘制描边，统一 2–3px 黑边。
// 用法：把本材质赋给 Sprite2D 的 Material 即可（切片用外扩法，移动端比后处理更稳，见 §11.9）。

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
	vec2 ps = texel * outline_width;

	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, ps.y)).a);
	a = max(a, texture(TEXTURE, UV + ps).a);
	a = max(a, texture(TEXTURE, UV - ps).a);
	a = max(a, texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(ps.x, -ps.y)).a);

	float sprite_a = texture(TEXTURE, UV).a;
	float outline = max(a - sprite_a, 0.0);

	COLOR = vec4(outline_color.rgb, outline);
}
