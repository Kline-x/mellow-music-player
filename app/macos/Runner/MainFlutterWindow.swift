import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 默认高质感大屏尺寸 1200x800 并居中
    let defaultWidth: CGFloat = 1200
    let defaultHeight: CGFloat = 800
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let originX = screenFrame.origin.x + (screenFrame.width - defaultWidth) / 2
    let originY = screenFrame.origin.y + (screenFrame.height - defaultHeight) / 2
    self.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)
    self.minSize = NSSize(width: 880, height: 600)

    // 沉浸式现代无边框窗口配置 (Full Size Content View)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    // 初始透明度设为 0，原生窗口底色设为深石墨黑 (0xFF12141A)，彻底杜绝 Flutter Metal 引擎首帧上屏前的黑屏闪现
    self.alphaValue = 0.0
    self.backgroundColor = NSColor(srgbRed: 18.0 / 255.0, green: 20.0 / 255.0, blue: 26.0 / 255.0, alpha: 1.0)

    // 首帧兜底保底：若 350ms 内未收到 Flutter 首帧通知，自动淡入显示，确保绝对无阻
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      guard let self = self, self.alphaValue < 1.0 else { return }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        self.animator().alphaValue = 1.0
      }
    }
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.registerMainWindow(self)
    }
  }
}
