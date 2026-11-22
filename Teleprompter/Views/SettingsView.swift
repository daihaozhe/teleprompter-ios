import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: PrompterSettings
    @Environment(\.dismiss) private var dismiss

    var onChange: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    slider(title: "字号", value: $settings.fontSize, range: 26...88, step: 2, unit: "pt")
                    slider(title: "行距", value: $settings.lineSpacing, range: 1.0...1.9, step: 0.02, unit: "x")
                    Picker("对齐", selection: Binding(
                        get: { settings.alignment },
                        set: { settings.alignment = $0 })) {
                        ForEach(TextAlignmentOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("文字")
                } footer: {
                    Text("iPhone 12 Pro Max 竖屏建议 42-52pt；横屏或离得远可以再加大。")
                }

                Section {
                    slider(title: "滚动速度", value: $settings.speed, range: 15...160, step: 1, unit: "pt/s")
                } header: {
                    Text("滚动")
                } footer: {
                    Text("参考：正常口播 45-65，慢速讲解 30 左右。拍摄中还能在提词页用 0.5x-2x 实时变速。")
                }

                Section {
                    Picker("背景", selection: $settings.backgroundColorIndex) {
                        Text("纯黑").tag(0)
                        Text("深灰").tag(1)
                        Text("深蓝").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Toggle("水平镜像", isOn: $settings.mirror)
                } header: {
                    Text("浮窗")
                } footer: {
                    Text("镜像只在你用分光镜提词器硬件时才需要打开。浮窗的透明度和位置由系统画中画控制，拖动窗口边缘即可缩放。")
                }

                Section {
                    Button("恢复默认设置") {
                        settings.fontSize = 46
                        settings.speed = 55
                        settings.lineSpacing = 1.28
                        settings.alignment = .center
                        settings.mirror = false
                        settings.backgroundColorIndex = 0
                        onChange()
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onChange()
                        dismiss()
                    }
                }
            }
        }
    }

    private func slider(title: String,
                        value: Binding<Double>,
                        range: ClosedRange<Double>,
                        step: Double,
                        unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: step < 1 ? "%.2f%@ " : "%.0f%@ ", value.wrappedValue, unit))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
