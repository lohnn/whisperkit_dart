# Whisper Dart Wrapper

A Dart FFI wrapper for [WhisperKit](https://github.com/argentlabs/WhisperKit), enabling high-performance speech-to-text on macOS using CoreML.

## Prerequisites

*   **macOS**: This wrapper relies on WhisperKit, which is optimized for Apple Silicon and macOS.
*   **Xcode**: Required to build the native Swift library.

## Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-repo/whisper_dart.git
    cd whisper_dart
    ```

2.  **Build the native library**:
    The native library is located in `native/`. You can build it using Swift Package Manager:
    ```bash
    cd native
    swift build -c release
    cd ..
    ```

3.  **Get Dart dependencies**:
    ```bash
    dart pub get
    ```

## CLI Usage

Run the CLI tool from the project root:

```bash
dart run bin/whisper_dart.dart -a <audio_file> [options]
```

### Options

*   `-a, --audio` (Mandatory): Path to the input audio file (e.g., `jfk.wav`).
*   `-m, --model`: Path to a custom model or a model alias.
    *   **Default**: `distil*large-v3` (automatically downloaded if not found).
    *   **Aliases**: `distil`, `large`, `medium`, `small`, `base`, `tiny`.
*   `-f, --format`: Output format.
    *   `text` (Default): Plain text transcript.
    *   `json`: Raw JSON output.
    *   `verbose_json`: Detailed JSON with segments and tokens.
    *   `clean_verbose_json`: Optimized JSON for storage (cleaned text, word timestamps).
*   `-w, --word-timestamps`: Enable word-level timestamps (useful for `verbose_json`).
*   `-h, --help`: Show usage information.

### Examples

**Basic Transcription:**
```bash
dart run bin/whisper_dart.dart -a jfk.wav
```

**Using a Specific Model Alias:**
```bash
dart run bin/whisper_dart.dart -a jfk.wav -m base
```

**Generating Clean JSON with Word Timestamps:**
```bash
dart run bin/whisper_dart.dart -a jfk.wav --format clean_verbose_json
```

## Library Usage

You can use the `Whisper` class in your Dart code:

```dart
import 'dart:io';
import 'package:whisper_dart/whisper_dart.dart';

void main() async {
  final whisper = Whisper();
  
  // Initialize with default model
  await whisper.init(); 
  // Or specify a model: await whisper.init(model: WhisperModel(path: 'path/to/model'));

  try {
    // Transcribe
    final text = await whisper.transcribe(
      audioFile: File('jfk.wav'), 
      format: WhisperFormat.cleanVerboseJson,
    );
    print(text);
  } finally {
    whisper.dispose();
  }
}
```

## Storage & Data Handling

For podcast applications, we recommend using the **`clean_verbose_json`** format. This format is optimized for storage and usability.

### Data Structure Recommendation

The `clean_verbose_json` format outputs a minimized JSON structure:

**Fields Kept:**
*   **`language`**: Useful for metadata and filtering.
*   **`segments`**: The core data for syncing and navigation.
    *   `id`: Unique identifier.
    *   `start` / `end`: Timestamps for seeking and highlighting.
    *   `text`: The **cleaned** transcript text (stripped of metadata tags like `<|0.00|>`).
    *   `words`: Word-level timestamps (`word`, `start`, `end`).

**Fields Discarded (to save space):**
*   **Top-level `text`**: Redundant. Reconstruct the full transcript by joining the cleaned segment texts.
*   **`timings`**, **`tokens`**, **`tokenLogProbs`**: Unnecessary internal metrics.
*   **Model stats**: `avgLogprob`, `compressionRatio`, etc.

## Development

*   **Tests**: Run `dart test` to verify changes. Tests must adhere to lint rules.
*   **Linting**: Run `dart analyze` to check for code quality issues.
