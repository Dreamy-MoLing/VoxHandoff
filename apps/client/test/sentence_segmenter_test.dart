import 'package:agent_talk_client/domain/sentence_segmenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits Chinese sentences across arbitrary deltas', () {
    final segmenter = SentenceSegmenter();

    expect(segmenter.feed('你好，'), isEmpty);
    expect(segmenter.feed('世界。下一句'), ['你好，世界。']);
    expect(segmenter.pending, '下一句');
    expect(segmenter.flush(), ['下一句']);
    expect(segmenter.pending, isEmpty);
  });

  test('requires whitespace after ASCII punctuation', () {
    final segmenter = SentenceSegmenter();

    expect(segmenter.feed('Hello world.'), isEmpty);
    expect(segmenter.feed(' Next question?\nDone!'), [
      'Hello world.',
      'Next question?',
    ]);
    expect(segmenter.flush(), ['Done!']);
  });

  test('handles mixed Chinese and English text', () {
    final segmenter = SentenceSegmenter();

    expect(segmenter.feed('先说中文。Then say hi! Next'), ['先说中文。', 'Then say hi!']);
    expect(segmenter.flush(), ['Next']);
  });

  test('does not split a decimal and flushes incomplete text', () {
    final segmenter = SentenceSegmenter();

    expect(segmenter.feed('版本 1.2 尚未完成'), isEmpty);
    expect(segmenter.flush(), ['版本 1.2 尚未完成']);
  });

  test('includes closing quotes in the stable sentence', () {
    final segmenter = SentenceSegmenter();

    expect(segmenter.feed('他说“你好”。然后'), ['他说“你好”。']);
    expect(segmenter.flush(), ['然后']);
  });
}
