import 'dart:io';
import 'package:args/args.dart';
import 'package:whisper_dart/whisper_dart.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('model', abbr: 'm', help: 'Path to the model or model name')
    ..addOption(
      'audio',
      abbr: 'a',
      help: 'Path to the audio file',
      mandatory: true,
    )
    ..addOption(
      'format',
      abbr: 'f',
      help: 'Output format (text, json, verbose_json, clean_verbose_json)',
      defaultsTo: 'text',
    )
    ..addFlag(
      'word-timestamps',
      abbr: 'w',
      help: 'Enable word-level timestamps',
      negatable: false,
    )
    ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      stdout
        ..writeln('Usage: dart run bin/whisper_dart.dart [options]')
        ..writeln(parser.usage);
      exit(0);
    }

    final audioPath = results['audio'] as String;
    final modelPath = results['model'] as String?;
    final formatStr = results['format'] as String;
    final format = WhisperFormat.fromCliOption(formatStr);
    final wordTimestamps = results['word-timestamps'] as bool;

    // Model Aliases
    const aliases = WhisperModel.aliases;
    WhisperModel model;

    if (modelPath == null) {
      model = WhisperModel.distilLargeV3; // Default to distilled
      stdout.writeln('No model specified, using default: ${model.path}');
    } else if (aliases.containsKey(modelPath)) {
      model = aliases[modelPath]!;
      stdout.writeln('Using alias for model: ${model.path}');
    } else {
      model = WhisperModel(path: modelPath);
    }

    stdout.writeln('Initializing WhisperKit with model: ${model.path}...');
    final whisper = Whisper();
    await whisper.init(model: model);

    stdout.writeln('Transcribing $audioPath...');
    final stopwatch = Stopwatch()..start();
    final text = await whisper.transcribe(
      audioFile: File(audioPath),
      format: format,
      wordTimestamps: wordTimestamps,
    );
    stopwatch.stop();

    stdout
      ..writeln('Transcription completed in ${stopwatch.elapsed}:')
      ..writeln(text);

    whisper.dispose();
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln(parser.usage);
    exit(1);
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
