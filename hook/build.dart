import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    final packageRoot = config.packageRoot.toFilePath();
    final macosDir = Directory.fromUri(config.packageRoot.resolve('macos'));
    
    // 1. Build
    print('Building WhisperKit in macos/...');
    final buildResult = await Process.run(
      'swift',
      ['build', '-c', 'release'],
      workingDirectory: macosDir.path,
    );

    if (buildResult.exitCode != 0) {
      throw Exception('Failed to build WhisperKit: ${buildResult.stderr}');
    }

    final dylibPath = macosDir.uri.resolve('.build/release/libWhisperWrapper.dylib');
    
    output.assets.code.add(CodeAsset(
      package: 'whisper_dart',
      name: 'whisper_dart_bindings',
      linkMode: DynamicLoadingBundled(),
      file: dylibPath,
    ));
  });
}
