import 'dart:io';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    final packageRoot = config.packageRoot.toFilePath();
    final nativeDir = Directory.fromUri(config.packageRoot.resolve('native'));
    
    // 1. Clone if not present
    if (!nativeDir.existsSync()) {
      print('Cloning WhisperKit into ${nativeDir.path}...');
      final cloneResult = await Process.run(
        'git',
        ['clone', 'https://github.com/argmaxinc/WhisperKit', 'native'],
        workingDirectory: packageRoot,
      );
      if (cloneResult.exitCode != 0) {
        // Check if it failed because it already exists (race condition or partial)
        if (!nativeDir.existsSync()) {
           throw Exception('Failed to clone WhisperKit: ${cloneResult.stderr}');
        }
      }
    }

    // 2. Build
    print('Building WhisperKit...');
    final buildResult = await Process.run(
      'swift',
      ['build', '-c', 'release'],
      workingDirectory: nativeDir.path,
    );

    if (buildResult.exitCode != 0) {
      throw Exception('Failed to build WhisperKit: ${buildResult.stderr}');
    }
  });
}
