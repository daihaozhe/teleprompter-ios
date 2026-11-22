import AVFoundation
import AVKit
import Combine
import MediaPlayer
import UIKit
import SwiftUI

/// 负责把预渲染好的提词视频通过系统「画中画」浮到最上层。
/// 画中画是 iOS 上唯一允许覆盖在其它 App（包括系统相机）之上的浮层。
final class PiPController: NSObject, ObservableObject {

    @Published private(set) var isActive = false
    @Published private(set) var isSupported = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var hasItem = false
    @Published private(set) var progress: Double = 0

    let playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = UIColor.black.cgColor
        return layer
    }()

    private let player = AVPlayer()
    private var pipController: AVPictureInPictureController?
    private let keepAlive = KeepAliveAudio()
    private var statusObserver: NSKeyValueObservation?
    private var timeObserver: Any?
    private var desiredRate: Float = 1.0
    private var remoteCommandsConfigured = false

    override init() {
        super.init()
        player.actionAtItemEnd = .pause
        playerLayer.player = player
        configurePiP()
        observePlayer()
        observeTime()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    private func configurePiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else { return }
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
    }

    private func observePlayer() {
        statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observed, _ in
            let playing = observed.timeControlStatus == .playing
            DispatchQueue.main.async {
                self?.isPlaying = playing
            }
        }
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.15, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            guard let item = self.player.currentItem else { return }
            let total = CMTimeGetSeconds(item.duration)
            guard total.isFinite, total > 0 else { return }
            let value = CMTimeGetSeconds(time) / total
            if value.isFinite {
                self.progress = max(0, min(1, value))
            }
        }
    }

    // MARK: - 加载与播放

    func load(url: URL) {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        duration = seconds.isFinite ? seconds : 0
        hasItem = true
        progress = 0
        configureRemoteCommands()
    }

    func play() {
        activateAudioSession()
        keepAlive.start()
        player.play()
        if desiredRate != 1.0 {
            player.rate = desiredRate
        }
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }

    func restart() {
        player.seek(to: .zero)
        play()
    }

    func seek(toProgress value: Double) {
        guard let item = player.currentItem else { return }
        let seconds = CMTimeGetSeconds(item.duration)
        guard seconds.isFinite, seconds > 0 else { return }
        let clamped = max(0, min(1, value))
        let target = clamped * seconds
        progress = clamped
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: CMTime(seconds: 0.2, preferredTimescale: 600),
                    toleranceAfter: CMTime(seconds: 0.2, preferredTimescale: 600))
    }

    func skip(seconds: Double) {
        guard let item = player.currentItem else { return }
        let total = CMTimeGetSeconds(item.duration)
        guard total.isFinite, total > 0 else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let target = max(0, min(total, current + seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600),
                    toleranceAfter: CMTime(seconds: 0.1, preferredTimescale: 600))
        progress = target / total
    }

    func setRate(_ rate: Float) {
        desiredRate = rate
        guard player.currentItem != nil else { return }
        if player.timeControlStatus == .playing {
            player.rate = rate
        } else {
            player.play()
            player.rate = rate
        }
    }

    func reset() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        keepAlive.stop()
        duration = 0
        hasItem = false
        isActive = false
        progress = 0
        desiredRate = 1.0
    }

    // MARK: - 画中画

    func startPictureInPicture(retry: Int = 2) {
        guard let pipController else { return }
        activateAudioSession()
        keepAlive.start()

        if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        } else if retry > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.startPictureInPicture(retry: retry - 1)
            }
        }
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
        keepAlive.stop()
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)
    }

    /// 让 AirPods / 蓝牙自拍器 / 线控耳机的按键能在拍摄中控制提词
    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [5]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(seconds: 5)
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [5]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(seconds: -5)
            return .success
        }
    }
}

extension PiPController: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        keepAlive.stop()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        keepAlive.stop()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}

/// 把 AVPlayerLayer 放进 SwiftUI 层级（画中画需要一个 inline 的播放层）
struct PlayerLayerView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        view.attach(playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.attach(playerLayer)
    }
}

final class PlayerContainerView: UIView {

    func attach(_ playerLayer: AVPlayerLayer) {
        if playerLayer.superlayer === layer {
            playerLayer.frame = bounds
            return
        }
        playerLayer.removeFromSuperlayer()
        layer.addSublayer(playerLayer)
        playerLayer.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.frame = bounds }
    }
}
