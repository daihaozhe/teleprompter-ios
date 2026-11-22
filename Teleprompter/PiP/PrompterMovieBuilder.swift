import AVFoundation
import CoreText
import UIKit

/// 把整篇台词预渲染成一段「匀速向上滚动」的竖屏视频。
/// 预渲染的好处：滚动完全由 AVPlayer 驱动，配合 PiP 时最稳定，
/// 也不会因为主线程卡顿导致滚动抖动。
final class PrompterMovieBuilder {

    struct Output {
        let url: URL
        let duration: Double
        let travel: CGFloat
    }

    enum BuildError: LocalizedError {
        case emptyText
        case cancelled
        case setupFailed
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyText: return "台词是空的，先写点内容"
            case .cancelled: return "已取消"
            case .setupFailed: return "无法创建视频写入器"
            case .writeFailed(let message): return "生成失败：\(message)"
            }
        }
    }

    static let renderSize = CGSize(width: 720, height: 1280)
    static let framesPerSecond: Int32 = 30
    static let horizontalInset: CGFloat = 52
    static let verticalInset: CGFloat = 96
    private static let maxPathHeight: CGFloat = 200_000

    private let queue = DispatchQueue(label: "com.dhz.teleprompter.movie", qos: .userInitiated)
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func build(attributedText: NSAttributedString,
               speed: CGFloat,
               backgroundColor: UIColor,
               mirror: Bool,
               progress: @escaping (Double) -> Void,
               completion: @escaping (Swift.Result<Output, Error>) -> Void) {

        guard attributedText.length > 0 else {
            DispatchQueue.main.async { completion(.failure(BuildError.emptyText)) }
            return
        }

        cancelled = false
        let text = attributedText
        let safeSpeed = max(speed, 8)
        let bg = backgroundColor

        queue.async { [weak self] in
            guard let self else { return }
            do {
                let output = try self.render(text: text,
                                             speed: safeSpeed,
                                             backgroundColor: bg,
                                             mirror: mirror,
                                             progress: progress)
                DispatchQueue.main.async { completion(.success(output)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func render(text: NSAttributedString,
                        speed: CGFloat,
                        backgroundColor: UIColor,
                        mirror: Bool,
                        progress: @escaping (Double) -> Void) throws -> Output {

        let size = Self.renderSize
        let textWidth = size.width - Self.horizontalInset * 2

        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let fit = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            nil)

        let contentHeight = ceil(fit.height) + Self.verticalInset * 2
        let travel = max(contentHeight - size.height, size.height * 0.5)

        let duration = min(max(Double(travel / speed), 6.0), 900.0)
        let totalFrames = max(Int(duration * Double(Self.framesPerSecond)), 30)

        let path = CGMutablePath()
        path.addRect(CGRect(x: Self.horizontalInset,
                            y: Self.verticalInset,
                            width: textWidth,
                            height: Self.maxPathHeight))
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prompter-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            throw BuildError.setupFailed
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 3_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])

        guard writer.canAdd(input) else { throw BuildError.setupFailed }
        writer.add(input)

        guard writer.startWriting() else {
            throw BuildError.writeFailed(writer.error?.localizedDescription ?? "startWriting 失败")
        }
        writer.startSession(atSourceTime: .zero)

        var frameIndex = 0
        var lastPercent = -1

        while frameIndex < totalFrames {
            if cancelled {
                input.markAsFinished()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: url)
                throw BuildError.cancelled
            }

            var waitCount = 0
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.004)
                waitCount += 1
                if waitCount > 2500 {
                    throw BuildError.writeFailed("编码器长时间未就绪")
                }
            }

            guard let pool = adaptor.pixelBufferPool else {
                throw BuildError.writeFailed("像素缓冲池不可用")
            }

            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else {
                throw BuildError.writeFailed("无法创建像素缓冲")
            }

            let offset = CGFloat(frameIndex) / CGFloat(Self.framesPerSecond) * speed
            Self.draw(frame: frame,
                      offset: offset,
                      backgroundColor: backgroundColor,
                      mirror: mirror,
                      into: buffer,
                      size: size)

            let pts = CMTime(value: CMTimeValue(frameIndex), timescale: Self.framesPerSecond)
            if !adaptor.append(buffer, withPresentationTime: pts) {
                throw BuildError.writeFailed(writer.error?.localizedDescription ?? "帧写入失败")
            }

            let percent = Int(Double(frameIndex) / Double(totalFrames) * 100.0)
            if percent != lastPercent {
                lastPercent = percent
                DispatchQueue.main.async { progress(Double(percent) / 100.0) }
            }

            frameIndex += 1
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else {
            throw BuildError.writeFailed(writer.error?.localizedDescription ?? "写入未完成")
        }

        DispatchQueue.main.async { progress(1.0) }
        return Output(url: url, duration: duration, travel: travel)
    }

    private static func draw(frame: CTFrame,
                             offset: CGFloat,
                             backgroundColor: UIColor,
                             mirror: Bool,
                             into buffer: CVPixelBuffer,
                             size: CGSize) {

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(data: base,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else { return }

        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // 翻转成 UIKit 坐标系（y 向下）
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        if mirror {
            context.translateBy(x: size.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }

        // 整体向上移动 offset
        context.translateBy(x: 0, y: -offset)

        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }
}
