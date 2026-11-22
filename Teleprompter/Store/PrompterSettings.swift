import Foundation
import Combine
import UIKit

enum TextAlignmentOption: Int, CaseIterable, Identifiable {
    case leading = 0
    case center = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .leading: return "左对齐"
        case .center: return "居中"
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        }
    }
}

final class PrompterSettings: ObservableObject {
    private enum Key {
        static let fontSize = "tp.fontSize"
        static let speed = "tp.speed"
        static let lineSpacing = "tp.lineSpacing"
        static let opacity = "tp.opacity"
        static let alignment = "tp.alignment"
        static let mirror = "tp.mirror"
        static let backgroundColorIndex = "tp.bgIndex"
        static let pipVerticalPosition = "tp.pipVertical"
    }

    /// 正文字号（pt），iPhone 12 Pro Max 竖屏默认 46
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    /// 滚动速度，单位 pt/秒
    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Key.speed) }
    }

    /// 行距倍数
    @Published var lineSpacing: Double {
        didSet { defaults.set(lineSpacing, forKey: Key.lineSpacing) }
    }

    /// 浮窗背景不透明度
    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: Key.opacity) }
    }

    @Published var alignmentRaw: Int {
        didSet { defaults.set(alignmentRaw, forKey: Key.alignment) }
    }

    /// 镜像（配合分光镜提词器硬件使用）
    @Published var mirror: Bool {
        didSet { defaults.set(mirror, forKey: Key.mirror) }
    }

    @Published var backgroundColorIndex: Int {
        didSet { defaults.set(backgroundColorIndex, forKey: Key.backgroundColorIndex) }
    }

    /// 0 = 顶部, 1 = 居中
    @Published var pipVerticalPosition: Int {
        didSet { defaults.set(pipVerticalPosition, forKey: Key.pipVerticalPosition) }
    }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.fontSize: 46.0,
            Key.speed: 55.0,
            Key.lineSpacing: 1.28,
            Key.opacity: 0.86,
            Key.alignment: TextAlignmentOption.center.rawValue,
            Key.mirror: false,
            Key.backgroundColorIndex: 0,
            Key.pipVerticalPosition: 0
        ])

        fontSize = defaults.double(forKey: Key.fontSize)
        speed = defaults.double(forKey: Key.speed)
        lineSpacing = defaults.double(forKey: Key.lineSpacing)
        opacity = defaults.double(forKey: Key.opacity)
        alignmentRaw = defaults.integer(forKey: Key.alignment)
        mirror = defaults.bool(forKey: Key.mirror)
        backgroundColorIndex = defaults.integer(forKey: Key.backgroundColorIndex)
        pipVerticalPosition = defaults.integer(forKey: Key.pipVerticalPosition)
    }

    var alignment: TextAlignmentOption {
        get { TextAlignmentOption(rawValue: alignmentRaw) ?? .center }
        set { alignmentRaw = newValue.rawValue }
    }

    var backgroundColor: UIColor {
        switch backgroundColorIndex {
        case 1: return UIColor(white: 0.10, alpha: 1.0)
        case 2: return UIColor(red: 0.02, green: 0.06, blue: 0.16, alpha: 1.0)
        default: return .black
        }
    }

    var backgroundColorName: String {
        switch backgroundColorIndex {
        case 1: return "深灰"
        case 2: return "深蓝"
        default: return "纯黑"
        }
    }

    /// 根据当前设置生成带样式的台词富文本
    func attributedText(for text: String, fontSizeOverride: CGFloat? = nil) -> NSAttributedString {
        let size = fontSizeOverride ?? CGFloat(fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment.nsAlignment
        paragraph.lineHeightMultiple = CGFloat(lineSpacing)
        paragraph.paragraphSpacing = size * 0.55
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
            .kern: 0.6
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}
