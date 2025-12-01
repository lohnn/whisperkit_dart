import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:whisper_dart/whisper_dart.dart';

void main() {
  group('Whisper Integration Tests', () {
    late Whisper whisper;
    const audioPath = 'jfk.wav';

    setUp(() async {
      whisper = Whisper();
      await whisper.init(model: WhisperModel.distilLargeV3);
    });

    tearDown(() {
      whisper.dispose();
    });

    test('transcribe text format', () async {
      final result = await whisper.transcribe(audioFile: File(audioPath));
      expect(
        result,
        'And so, my fellow Americans, ask not what your country can do '
        'for you. Ask what you can do for your country.',
      );
    });

    test('transcribe clean_verbose_json format', () async {
      final result = await whisper.transcribe(
        audioFile: File(audioPath),
        format: WhisperFormat.cleanVerboseJson,
      );
      final decodedList = jsonDecode(result);

      // Define the expected structure
      // Note: Timestamps are floating point, so exact equality might be tricky
      // across machines/models.
      // However, for the same model and file, it should be deterministic.
      // If this becomes flaky, we might need a custom matcher for approximate
      // doubles.
      final expected = [
        {
          'language': 'en',
          'segments': [
            {
              'id': 0,
              'start': 0.34,
              'end': 7.42,
              'text':
                  'And so, my fellow Americans, ask not what your country can '
                  'do for you.',
              'words': [
                {'word': ' And', 'start': 0.34, 'end': 0.52},
                {'word': ' so,', 'start': 0.52, 'end': 0.9},
                {'word': ' my', 'start': 1.04, 'end': 1.22},
                {'word': ' fellow', 'start': 1.22, 'end': 1.56},
                {'word': ' Americans,', 'start': 1.56, 'end': 2.26},
                {'word': ' ask', 'start': 3.66, 'end': 3.78},
                {'word': ' not', 'start': 3.78, 'end': 4.32},
                {'word': ' what', 'start': 4.32, 'end': 5.54},
                {'word': ' your', 'start': 5.54, 'end': 5.8},
                {'word': ' country', 'start': 5.8, 'end': 6.32},
                {'word': ' can', 'start': 6.32, 'end': 6.62},
                {'word': ' do', 'start': 6.62, 'end': 6.84},
                {'word': ' for', 'start': 6.84, 'end': 7.06},
                {'word': ' you.', 'start': 7.06, 'end': 7.42},
              ],
            },
            {
              'id': 1,
              'start': 8.46,
              'end': 10.4,
              'text': 'Ask what you can do for your country.',
              'words': [
                {'word': ' Ask', 'start': 8.46, 'end': 8.56},
                {'word': ' what', 'start': 8.56, 'end': 8.78},
                {'word': ' you', 'start': 8.78, 'end': 9.08},
                {'word': ' can', 'start': 9.08, 'end': 9.34},
                {'word': ' do', 'start': 9.34, 'end': 9.58},
                {'word': ' for', 'start': 9.58, 'end': 9.8},
                {'word': ' your', 'start': 9.8, 'end': 9.96},
                {'word': ' country.', 'start': 9.96, 'end': 10.4},
              ],
            },
          ],
        },
      ];

      expect(decodedList, expected);
    });
  });
}
