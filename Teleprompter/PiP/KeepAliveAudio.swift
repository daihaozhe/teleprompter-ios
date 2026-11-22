import AVFoundation
import Foundation

/// 循环播放一段静音 WAV，让 App 在后台（切到系统相机时）仍被系统认为在播放音频，
/// 从而保证画中画窗口持续存在、视频持续滚动。
final class KeepAliveAudio {

    private var player: AVAudioPlayer?

    func start() {
        if player == nil {
            guard let url = Self.makeSilentWav(seconds: 2.0),
                  let audioPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0.02
            audioPlayer.prepareToPlay()
            player = audioPlayer
        }
        player?.play()
    }

    func stop() {
        player?.pause()
    }

    private static func makeSilentWav(seconds: Double) -> URL? {
        let sampleRate = 8000
        let channels = 1
        let bitsPerSample = 16
        let frameCount = Int(Double(sampleRate) * seconds)
        let dataSize = frameCount * channels * bitsPerSample / 8

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendUInt32(16)
        data.appendUInt16(1)
        data.appendUInt16(UInt16(channels))
        data.appendUInt32(UInt32(sampleRate))
        data.appendUInt32(UInt32(sampleRate * channels * bitsPerSample / 8))
        data.appendUInt16(UInt16(channels * bitsPerSample / 8))
        data.appendUInt16(UInt16(bitsPerSample))
        data.append(contentsOf: Array("data".utf8))
        data.appendUInt32(UInt32(dataSize))
        data.append(Data(count: dataSize))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tp-silence.wav")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        withUnsafeBytes(of: little) { append(contentsOf: $0) }
    }

    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        withUnsafeBytes(of: little) { append(contentsOf: $0) }
    }
}
