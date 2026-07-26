#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uState;
uniform float uAudioLevel;
uniform float uPlaybackLevel;
uniform vec3 uStateColor;
uniform float uReducedMotion;
uniform float uDetail;
uniform float uFaultPulse;

out vec4 fragColor;

float ring(vec2 point, float radius, float width) {
  return 1.0 - smoothstep(width, width + 0.006, abs(length(point) - radius));
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uSize) / min(uSize.x, uSize.y);
  float time = uReducedMotion > 0.5 ? 0.0 : uTime * 6.2831853;
  float angle = atan(uv.y, uv.x);
  float radius = length(uv);
  float activity = clamp(max(uAudioLevel, uPlaybackLevel), 0.0, 1.0);

  float outer = ring(uv, 0.41 + activity * 0.012, 0.008);
  float inner = ring(uv, 0.28, 0.005);
  float ripple = ring(
    uv,
    0.33 + 0.025 * sin(time + angle * 3.0) * activity,
    0.004
  );
  float scan = uReducedMotion > 0.5
      ? 0.0
      : smoothstep(0.018, 0.0, abs(fract(uv.y * 7.0 - uTime * 2.0) - 0.5));
  float fault = uFaultPulse * step(0.72, fract(angle * 2.4 + uTime * 1.7));
  float energy = outer * 0.45 + inner * 0.22 + ripple * uDetail * 0.38;
  energy += scan * 0.035 * (1.0 - smoothstep(0.18, 0.48, radius));
  energy += fault * ring(uv, 0.355, 0.012) * 0.18;

  vec3 color = uStateColor * energy;
  float alpha = clamp(energy, 0.0, 0.7);
  fragColor = vec4(color, alpha);
}
