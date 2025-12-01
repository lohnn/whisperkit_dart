import 'dart:io';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    print('DEBUG: Hook started');
    final packageRoot = config.packageRoot.toFilePath();
    final nativeDir = Directory.fromUri(config.packageRoot.resolve('native'));
    print('DEBUG: Native dir: ${nativeDir.path}');
    
    // 1. Clone if not present
    if (!nativeDir.existsSync()) {
      print('Cloning WhisperKit into ${nativeDir.path}...');
      final cloneResult = await Process.run(
        'git',
        ['clone', 'https://github.com/argmaxinc/WhisperKit', 'native'],
        workingDirectory: packageRoot,
      );
      print('DEBUG: Clone exit code: ${cloneResult.exitCode}');
      if (cloneResult.exitCode != 0) {
        print('DEBUG: Clone stderr: ${cloneResult.stderr}');
        // Check if it failed because it already exists (race condition or partial)
        if (!nativeDir.existsSync()) {
           throw Exception('Failed to clone WhisperKit: ${cloneResult.stderr}');
        }
      }
    } else {
      print('DEBUG: Native dir already exists');
    }

    // 2. Build
    print('Building WhisperKit...');
    final buildResult = await Process.run(
      'swift',
      ['build', '-c', 'release'],
      workingDirectory: nativeDir.path,
    );
    print('DEBUG: Build exit code: ${buildResult.exitCode}');

    if (buildResult.exitCode != 0) {
      print('DEBUG: Build stderr: ${buildResult.stderr}');
      throw Exception('Failed to build WhisperKit: ${buildResult.stderr}');
    }
  });
}
