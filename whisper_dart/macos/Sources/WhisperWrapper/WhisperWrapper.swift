import Foundation
import WhisperKit

@_cdecl("whisper_init")
public func whisper_init(modelPath: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    let path = modelPath.map { String(cString: $0) }
    
    // We need to run this in a synchronous context for the C API, 
    // but WhisperKit is async. We'll use a semaphore or similar to wait.
    // Ideally, we'd wrap this in a class that holds the pipe.
    
    let wrapper = WhisperWrapper()
    let success = wrapper.initialize(modelPath: path)
    
    if success {
        return Unmanaged.passRetained(wrapper).toOpaque()
    } else {
        return nil
    }
}

@_cdecl("whisper_transcribe")
public func whisper_transcribe(context: UnsafeMutableRawPointer, audioPath: UnsafePointer<CChar>, format: UnsafePointer<CChar>?, wordTimestamps: Bool) -> UnsafeMutablePointer<CChar>? {
    let wrapper = Unmanaged<WhisperWrapper>.fromOpaque(context).takeUnretainedValue()
    let audioPathStr = String(cString: audioPath)
    let formatStr = format.map { String(cString: $0) } ?? "text"
    
    if let result = wrapper.transcribe(audioPath: audioPathStr, format: formatStr, wordTimestamps: wordTimestamps) {
        return strdup(result)
    }
    
    return nil
}

@_cdecl("whisper_free")
public func whisper_free(context: UnsafeMutableRawPointer) {
    Unmanaged<WhisperWrapper>.fromOpaque(context).release()
}

@_cdecl("whisper_free_string")
public func whisper_free_string(string: UnsafeMutablePointer<CChar>) {
    free(string)
}

class WhisperWrapper {
    var pipe: WhisperKit?
    
    func initialize(modelPath: String?) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        Task {
            do {
                if let modelPath = modelPath {
                     let config = WhisperKitConfig(model: modelPath)
                     self.pipe = try await WhisperKit(config)
                } else {
                    self.pipe = try await WhisperKit()
                }
                success = true
            } catch {
                print("Error initializing WhisperKit: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return success
    }
    
    func transcribe(audioPath: String, format: String, wordTimestamps: Bool) -> String? {
        guard let pipe = pipe else { return nil }
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultString: String?
        
        Task {
            do {
                let options = DecodingOptions(wordTimestamps: wordTimestamps)
                let transcription = try await pipe.transcribe(audioPath: audioPath, decodeOptions: options)
                
                switch format {
                case "json":
                    // Simple JSON: {"text": "..."}
                    let text = transcription.map { $0.text }.joined(separator: " ")
                    let simpleJson = ["text": text]
                    let jsonData = try JSONEncoder().encode(simpleJson)
                    resultString = String(data: jsonData, encoding: .utf8)
                    
                case "verbose_json":
                    // Full JSON using TranscriptionResultStruct
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let jsonData = try encoder.encode(transcription)
                    resultString = String(data: jsonData, encoding: .utf8)
                    
                default: // "text"
                    resultString = transcription.map { $0.text }.joined(separator: " ")
                }
                
            } catch {
                print("Error transcribing: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return resultString
    }
}
