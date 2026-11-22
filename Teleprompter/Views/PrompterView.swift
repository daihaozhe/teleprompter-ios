import AVKit
import SwiftUI

struct PrompterView: View {
    let script: ScriptItem

    @EnvironmentObject private var settings: PrompterSettings
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = PiPController()
    @State private var builder = PrompterMovieBuilder()

    @State private var isBuilding = false
    @State private var buildProgress: Double = 0
    @State private var errorMessage: String?
    @State private var builtSignature = ""
    @State private var countdown: Int?
    @State private var showSettings = false
    @State private var playbackRate: Float = 1.0

    @State private var scrubValue: Double?
    @State private var dragBase: Double?

    private let rateOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private var signature: String {
        [
            String(settings.fontSize),
            String(settings.lineSpacing),
            String(settings.speed),
            String(settings.alignmentRaw),
            String(settings.backgroundColorIndex),
            String(settings.mirror),
            String(script.body.count),
            String(script.body.hashValue)
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                    .padding(.top, 8)

                scrubBar

                if engine.isActive {
                    floatingBanner
                        .padding(.top, 10)
                }

                Spacer(minLength: 6)

                controls
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(script.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        close()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    rebuildIfNeeded(force: true)
                }
            }
            .alert("出错了", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })) {
                Button("知道了") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                rebuildIfNeeded()
            }
            .onDisappear {
                close()
            }
        }
    }

    // MARK: - 预览 + 手动滑动

    private var preview: some View {
        ZStack {
            PlayerLayerView(playerLayer: engine.playerLayer)
                .frame(width: 216, height: 384)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            if isBuilding {
                buildingOverlay
            }

            if let countdown {
                countdownOverlay(countdown)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if dragBase == nil {
                    dragBase = engine.progress
                }
                let base = dragBase ?? 0
                let delta = -Double(value.translation.height) / 420.0
                engine.seek(toProgress: base + delta)
            }
            .onEnded { _ in
                dragBase = nil
            }
    }

    private var scrubBar: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { scrubValue ?? engine.progress },
                    set: { scrubValue = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing, let value = scrubValue {
                        engine.seek(toProgress: value)
                        scrubValue = nil
                    }
                }
            )
            .tint(.white)
            .disabled(isBuilding)

            HStack {
                Text(timeText((scrubValue ?? engine.progress) * engine.duration))
                Spacer()
                Text("上滑快进 · 下滑回退")
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(timeText(engine.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    private var buildingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: buildProgress)
                .progressViewStyle(.linear)
                .tint(.white)
                .frame(width: 132)
            Text("正在排版 \(Int(buildProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func countdownOverlay(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 12)
            .transition(.scale.combined(with: .opacity))
    }

    private var floatingBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("已浮起，回桌面打开「相机」")
                .font(.footnote.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.10)))
    }

    // MARK: - 控制区

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 30) {
                secondaryButton(icon: "gobackward.5", label: "后退 5s") {
                    engine.skip(seconds: -5)
                }

                Button {
                    engine.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .disabled(isBuilding)

                secondaryButton(icon: "goforward.5", label: "前进 5s") {
                    engine.skip(seconds: 5)
                }
            }

            HStack(spacing: 10) {
                Button {
                    startCountdown()
                } label: {
                    Label("3 秒后开始", systemImage: "timer")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .foregroundStyle(.white)
                .disabled(isBuilding)

                Button {
                    togglePiP()
                } label: {
                    Label(engine.isActive ? "收起浮窗" : "浮到相机上",
                          systemImage: "rectangle.on.rectangle")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.accentColor.opacity(0.85)))
                }
                .foregroundStyle(.white)
                .disabled(isBuilding)
            }

            HStack(spacing: 7) {
                ForEach(rateOptions, id: \.self) { rate in
                    Button {
                        playbackRate = rate
                        engine.setRate(rate)
                    } label: {
                        Text(rateLabel(rate))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 42)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(playbackRate == rate
                                               ? Color.white
                                               : Color.white.opacity(0.10))
                            )
                            .foregroundStyle(playbackRate == rate ? Color.black : Color.white)
                    }
                }
            }
            .disabled(isBuilding)

            Text("浮窗是系统画中画，不会录进画面。拍摄中可用 AirPods 或蓝牙耳机的按键暂停 / 前后跳 5 秒。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private func secondaryButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: 66, height: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10)))
        }
    }

    // MARK: - 动作

    private func togglePiP() {
        if engine.isActive {
            engine.stopPictureInPicture()
        } else {
            engine.startPictureInPicture()
        }
    }

    private func startCountdown(remaining: Int = 3) {
        if remaining <= 0 {
            countdown = nil
            engine.restart()
            return
        }
        countdown = remaining
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startCountdown(remaining: remaining - 1)
        }
    }

    private func rateLabel(_ rate: Float) -> String {
        if rate == rate.rounded() {
            return "\(Int(rate))x"
        }
        return String(format: "%.2gx", rate)
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func rebuildIfNeeded(force: Bool = false) {
        let sig = signature
        if !force, sig == builtSignature, engine.hasItem {
            return
        }

        builder.cancel()
        engine.reset()

        isBuilding = true
        buildProgress = 0

        let attributed = settings.attributedText(for: script.body)
        let speed = CGFloat(settings.speed)
        let background = settings.backgroundColor
        let mirrored = settings.mirror

        builder.build(attributedText: attributed,
                      speed: speed,
                      backgroundColor: background,
                      mirror: mirrored,
                      progress: { value in
            buildProgress = value
        }, completion: { result in
            isBuilding = false
            switch result {
            case .success(let output):
                builtSignature = sig
                engine.load(url: output.url)
                engine.seek(toProgress: 0)
            case .failure(let error):
                if let buildError = error as? PrompterMovieBuilder.BuildError,
                   case .cancelled = buildError {
                    return
                }
                errorMessage = error.localizedDescription
            }
        })
    }

    private func close() {
        builder.cancel()
        engine.reset()
    }
}
