#version 440

// The Horizon layout's header lighting: the mosque name and the hijri date
// over the sky, lit by the sun or the moon passing behind them.
//
//   sky      the painted sky behind the header band (HorizonBackground)
//   letters  the header text in white, as a coverage mask
//
// Deep navy letters while the sky behind the header is bright (darkInk),
// with a warm glow around them when the sun is near, as if backlit.
// Silver letters once it is dark: wherever something brighter than the
// sky lies behind them - the moon, its halo, a low sun - the sky right
// around the strokes is shaded, and where that background is about as
// bright as the letters themselves they also get a crisp dark outline;
// near the moon the letters turn white and the edges facing it catch a
// thin rim of moonlight.
//
// Distances are in the item's logical pixels (bandSize). Compiled to
// headerlight.frag.qsb by build-shaders.sh at the top of the repository;
// the compiled file is not committed.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 bandSize;   // size of the band, logical pixels
    float darkInk;   // 1: navy letters (bright sky), 0: silver (dark sky)
    float skyLum;    // brightness of the plain sky behind the header
    vec4 sun;        // x, y, radius, up (0/1)
    vec4 moon;       // x, y, radius, up (0/1)
};

layout(binding = 1) uniform sampler2D sky;
layout(binding = 2) uniform sampler2D letters;

const vec3 NAVY = vec3(13.0, 34.0, 66.0) / 255.0;
const vec3 SILVER = vec3(206.0, 216.0, 238.0) / 255.0;
const vec3 NIGHT = vec3(10.0, 20.0, 48.0) / 255.0;
const vec3 WARM = vec3(255.0, 207.0, 107.0) / 255.0;
const vec3 MOONLIGHT = vec3(226.0, 233.0, 255.0) / 255.0;

// One of eight directions around a circle. Computed rather than kept in a
// constant array: the GLSL 1.20 that Qt hands to OpenGL compatibility
// contexts gets no constant arrays from NVIDIA's compiler.
vec2 ring(int i)
{
    float a = float(i) * 0.78539816;
    return vec2(cos(a), sin(a));
}

float cover(vec2 p)
{
    return texture(letters, p / bandSize).a;
}

float luma(vec3 c)
{
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 screenBlend(vec3 c, vec3 light, float a)
{
    return 1.0 - (1.0 - c) * (1.0 - light * a);
}

// The letters blurred over two rings around p: a soft halo of them
float halo(vec2 p, float r1, float r2)
{
    float sum = cover(p);
    float w = 1.0;
    for (int i = 0; i < 8; ++i) {
        sum += 0.8 * cover(p + ring(i) * r1) + 0.45 * cover(p + ring(i) * r2);
        w += 0.8 + 0.45;
    }
    return sum / w;
}

// How much of a letter's edge facing the moon lies at q
float facing(vec2 q)
{
    vec2 to = moon.xy - q;
    float d = max(length(to), 0.001);
    return max(0.0, cover(q) - cover(q + to / d));
}

void main()
{
    vec2 p = qt_TexCoord0 * bandSize;
    vec4 s = texture(sky, qt_TexCoord0);
    float alpha = s.a;
    vec3 c = alpha > 0.0 ? s.rgb / alpha : vec3(0.0);
    float m = cover(p);
    float bgLum = luma(c);
    vec3 ink;

    if (darkInk > 0.5) {
        ink = NAVY;
        if (sun.w > 0.5) {
            vec2 d = p - sun.xy;
            float near = exp(-dot(d, d) / (2.0 * pow(sun.z * 3.2, 2.0)));
            float a = clamp(halo(p, 2.0, 4.2) * 2.2, 0.0, 1.0) * near * 0.95;
            c = screenBlend(c, WARM, a);
        }
    } else {
        // shade the sky around the strokes where it is brighter than the sky
        float bright = smoothstep(0.04, 0.3, bgLum - skyLum);
        float shade = clamp(halo(p, 1.0, 2.2) * 2.2, 0.0, 1.0) * bright * 0.7;
        c = mix(c, NIGHT, shade);
        // a crisp outline right around the strokes, as dark as the
        // background is close to the letters' own brightness
        float close = 1.0 - smoothstep(0.12, 0.38, abs(0.86 - bgLum));
        float outline = clamp(halo(p, 0.8, 1.6) * 3.0, 0.0, 1.0) * close * 0.92;
        c = mix(c, NIGHT, outline);
        float lit = 0.0;
        if (moon.w > 0.5) {
            float d = length(p - moon.xy);
            float nearMoon = exp(-pow(d / (moon.z * 3.2), 2.0));
            float rim = facing(p);
            float glow = rim;
            for (int i = 0; i < 8; ++i) {
                glow += 0.8 * facing(p + ring(i) * 1.5) + 0.45 * facing(p + ring(i) * 3.0);
            }
            glow /= 1.0 + 8.0 * (0.8 + 0.45);
            c = screenBlend(c, MOONLIGHT, min(0.6, glow * 2.5 * nearMoon));
            lit = clamp(max(nearMoon * 1.3, rim * nearMoon * 1.5), 0.0, 1.0);
        }
        ink = mix(SILVER, vec3(1.0), lit);
    }

    fragColor = vec4(mix(c, ink, m) * alpha, alpha) * qt_Opacity;
}
