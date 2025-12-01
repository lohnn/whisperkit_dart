#ifndef WhisperWrapper_h
#define WhisperWrapper_h

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void* whisper_init(const char* model_path);
const char* whisper_transcribe(void* context, const char* audio_path, const char* format, bool word_timestamps);
void whisper_free(void* context);
void whisper_free_string(const char* string);

#ifdef __cplusplus
}
#endif

#endif /* WhisperWrapper_h */
