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

float softField(float radius, float center, float spread) {
  float delta = (radius - center) / spread;
  return exp(-delta * delta);
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uSize) / min(uSize.x, uSize.y);
  float time = uReducedMotion > 0.5 ? 0.0 : uTime * 6.2831853;
  float angle = atan(uv.y, uv.x);
  float radius = length(uv);
  float activity = clamp(max(uAudioLevel, uPlaybackLevel), 0.0, 1.0);
  float state = clamp(uState, 0.0, 10.0);
  float recording = 1.0 - step(0.5, abs(state - 1.0));
  float transcribing = 1.0 - step(0.5, abs(state - 2.0));
  float submitting = 1.0 - step(0.5, abs(state - 4.0));
  float working = 1.0 - step(0.5, abs(state - 5.0));
  float speaking = 1.0 - step(0.5, abs(state - 6.0));
  float approval = 1.0 - step(0.5, abs(state - 7.0));
  float failed = 1.0 - step(0.5, abs(state - 9.0));
  float uncertain = 1.0 - step(0.5, abs(state - 10.0));
  float activeMotion = max(
    max(recording, transcribing),
    max(max(submitting, working), max(speaking, max(approval, uncertain)))
  );

  float stateWave = sin(angle * (3.0 + mod(state, 5.0)) + time * (0.35 + working));
  float morphRadius = 0.29
      + stateWave * (0.006 + activity * 0.022)
      + recording * activity * 0.018
      + speaking * activity * 0.026;
  float outer = ring(uv, 0.42 + activity * 0.014, 0.007);
  float inner = ring(uv, morphRadius, 0.006);
  float ripple = ring(
    uv,
    0.34 + 0.018 * stateWave * (activity + working * 0.35),
    0.004
  );
  float scanEnabled = max(transcribing, max(submitting, working));
  float scan = uReducedMotion > 0.5 || scanEnabled < 0.5
      ? 0.0
      : smoothstep(0.018, 0.0, abs(fract(uv.y * 7.0 - uTime * 2.0) - 0.5));
  float fault = failed * uFaultPulse * step(0.72, fract(angle * 2.4 + uTime * 1.7));
  float brokenArc = uncertain * step(0.62, fract(angle * 1.7 + 0.24));
  float halo = softField(radius, 0.20 + activity * 0.025, 0.17);
  float coreGlow = exp(-radius * radius * (18.0 - activity * 5.0));
  float energy = outer * (0.26 + activeMotion * 0.18);
  energy += inner * (0.22 + approval * 0.16);
  energy += ripple * uDetail * (0.18 + activity * 0.35 + working * 0.12);
  energy += halo * (0.025 + activeMotion * 0.035 + activity * 0.06);
  energy += coreGlow * (0.06 + activity * 0.12);
  energy += scan * 0.05 * (1.0 - smoothstep(0.18, 0.48, radius));
  energy += fault * ring(uv, 0.355, 0.012) * 0.2;
  energy *= 1.0 - brokenArc * ring(uv, 0.42, 0.025) * 0.75;

  vec3 color = uStateColor * energy;
  float alpha = clamp(energy, 0.0, 0.78);
  fragColor = vec4(color, alpha);
}
