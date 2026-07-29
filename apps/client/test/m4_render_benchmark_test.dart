import 'package:agent_talk_client/presentation/m4_render_benchmark.dart';
import 'package:agent_talk_client/presentation/mvp_render_benchmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop environment flag requests the M4 render benchmark', () {
    expect(
      shouldRunM4RenderBenchmark(const {'VOXHANDOFF_M4_RENDER_BENCHMARK': '1'}),
      isTrue,
    );
    expect(shouldRunM4RenderBenchmark(const {}), isFalse);
  });

  test('build-time flag requests the benchmark on mobile', () {
    expect(shouldRunM4RenderBenchmark(const {}, buildEnabled: true), isTrue);
  });

  test('MVP HomeScreen benchmark has independent runtime and build flags', () {
    expect(
      shouldRunMvpRenderBenchmark(const {
        'VOXHANDOFF_MVP_RENDER_BENCHMARK': '1',
      }),
      isTrue,
    );
    expect(shouldRunMvpRenderBenchmark(const {}), isFalse);
    expect(shouldRunMvpRenderBenchmark(const {}, buildEnabled: true), isTrue);
  });
}
