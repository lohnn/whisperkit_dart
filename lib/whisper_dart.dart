import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:whisper_dart/generated_bindings.dart';

/// The format of the output.
enum WhisperFormat {
  /// Plain text output.
  text,

  /// JSON output.
  json,

  /// Verbose JSON output.
  verboseJson,

  /// Clean verbose JSON output (custom format).
  cleanVerboseJson
  ;

  /// The string representation of the format for the native library.
  String get nativeValue => switch (this) {
    WhisperFormat.text => 'text',
    WhisperFormat.json => 'json',
    WhisperFormat.verboseJson => 'verbose_json',
    WhisperFormat.cleanVerboseJson => 'verbose_json',
  };

  /// Parses a string from the CLI options.
  static WhisperFormat fromCliOption(String option) => switch (option) {
    'text' => WhisperFormat.text,
    'json' => WhisperFormat.json,
    'verbose_json' => WhisperFormat.verboseJson,
    'clean_verbose_json' => WhisperFormat.cleanVerboseJson,
    _ => throw FormatException('Invalid format: $option'),
  };
}

/// A model for the Whisper engine.
class WhisperModel {
  /// Create a new [WhisperModel].
  const WhisperModel({required this.path});

  /// The path to the model file.
  final String path;

  /// Distilled Large V3 model (default).
  static const distilLargeV3 = WhisperModel(path: 'distil*large-v3');

  /// Large V3 model.
  static const largeV3 = WhisperModel(path: 'openai_whisper-large-v3');

  /// Medium model.
  static const medium = WhisperModel(path: 'openai_whisper-medium');

  /// Small model.
  static const small = WhisperModel(path: 'openai_whisper-small');

  /// Base model.
  static const base = WhisperModel(path: 'openai_whisper-base');

  /// Tiny model.
  static const tiny = WhisperModel(path: 'openai_whisper-tiny');

  /// Map of aliases to models.
  static const Map<String, WhisperModel> aliases = {
    'distil': distilLargeV3,
    'large': largeV3,
    'medium': medium,
    'small': small,
    'base': base,
    'tiny': tiny,
  };
}

/// {@template whisper}
/// A wrapper around the WhisperKit native library.
/// {@endtemplate}
class Whisper {
  /// {@macro whisper}
  Whisper() {
    // Determine the path to the dynamic library
    // For development, it's in native/.build/release/libWhisperWrapper.dylib
    // In a real app, you'd need to handle platform-specific paths.
    final libraryPath = p.join(
      Directory.current.path,
      'native',
      '.build',
      'release',
      'libWhisperWrapper.dylib',
    );

    if (Platform.isMacOS) {
      _dylib = DynamicLibrary.open(libraryPath);
    } else {
      throw UnsupportedError('Only macOS is supported for now');
    }

    _bindings = WhisperBindings(_dylib);
  }

  late final WhisperBindings _bindings;
  late final DynamicLibrary _dylib;

  Pointer<Void>? _context;

  /// Initialize the Whisper model.
  ///
  /// [model] is optional. If not provided, the default model is used.
  Future<void> init({WhisperModel? model}) async {
    // We run this in an isolate or just call it. Since the C function waits on
    // a semaphore, calling it on the main isolate will block the UI/event loop.
    // For a CLI, it might be fine, but for an app, we should use compute or
    // Isolate.run.
    // For simplicity in this wrapper, we'll just call it, but note the
    // blocking nature.

    // Actually, since we are in Dart, we can't easily offload FFI calls that
    // block to another thread without using Isolate.spawn or similar.
    // However, for this task, we'll assume blocking is acceptable for
    // initialization.

    Pointer<Char> modelPathPtr = nullptr;
    if (model != null) {
      modelPathPtr = model.path.toNativeUtf8().cast<Char>();
    }

    try {
      _context = _bindings.whisper_init(modelPathPtr);
      if (_context == nullptr) {
        throw Exception('Failed to initialize WhisperKit');
      }
    } finally {
      if (modelPathPtr != nullptr) {
        calloc.free(modelPathPtr);
      }
    }
  }

  /// Transcribe an audio file.
  ///
  /// [format] can be [WhisperFormat.text], [WhisperFormat.json],
  /// [WhisperFormat.verboseJson], or [WhisperFormat.cleanVerboseJson].
  /// [wordTimestamps] enables word-level timestamps in the output
  /// (useful for verbose_json).
  Future<String> transcribe({
    required File audioFile,
    WhisperFormat format = WhisperFormat.text,
    bool wordTimestamps = false,
  }) async {
    if (_context == nullptr) {
      throw StateError('Whisper not initialized. Call init() first.');
    }

    // Handle clean_verbose_json
    final isCleanVerboseJson = format == WhisperFormat.cleanVerboseJson;
    final effectiveFormat = format.nativeValue;
    // Force word timestamps if clean_verbose_json is requested,
    // or use user preference
    final effectiveWordTimestamps = isCleanVerboseJson || wordTimestamps;

    final audioPathPtr = audioFile.path.toNativeUtf8().cast<Char>();
    final formatPtr = effectiveFormat.toNativeUtf8().cast<Char>();

    try {
      final resultPtr = _bindings.whisper_transcribe(
        _context!,
        audioPathPtr,
        formatPtr,
        effectiveWordTimestamps,
      );
      if (resultPtr == nullptr) {
        throw Exception('Failed to transcribe audio');
      }

      final result = resultPtr.cast<Utf8>().toDartString();
      _bindings.whisper_free_string(resultPtr);

      if (isCleanVerboseJson) {
        return _processCleanVerboseJson(result);
      }

      return result;
    } finally {
      calloc
        ..free(audioPathPtr)
        ..free(formatPtr);
    }
  }

  String _processCleanVerboseJson(String jsonString) {
    final decoded = jsonDecode(jsonString);

    return switch (decoded) {
      [final Map<String, dynamic> result, ...] => jsonEncode([
        {
          if (result case {'language': final String language})
            'language': language,
          if (result case {'segments': final List<dynamic> segments})
            'segments': [
              for (final segment in segments)
                if (segment case {
                  'id': final int id,
                  'start': final num start,
                  'end': final num end,
                  'text': final String text,
                })
                  {
                    'id': id,
                    'start': start,
                    'end': end,
                    'text': _cleanText(text),
                    if (segment case {'words': final List<dynamic> words})
                      'words': [
                        for (final word in words)
                          if (word case {
                            'word': final String w,
                            'start': final num s,
                            'end': final num e,
                          })
                            {'word': w, 'start': s, 'end': e},
                      ],
                  },
            ],
        },
      ]),
      _ => jsonString,
    };
  }

  String _cleanText(String text) {
    // Strip special metadata tokens like <|startoftranscript|>, <|en|>,
    // <|0.00|>, <|transcribe|>
    // Regex to match <|...|>
    return text.replaceAll(RegExp(r'<\|.*?\|>'), '').trim();
  }

  /// Free resources.
  void dispose() {
    if (_context != nullptr) {
      _bindings.whisper_free(_context!);
      _context = nullptr;
    }
  }
}
