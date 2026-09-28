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
    // 设置原生窗口背景色为 Mellow 主题白瓷色 (0xF5F7FB)，彻底杜绝 Flutter 首帧绘制前的黑屏闪现
    self.backgroundColor = NSColor(srgbRed: 245.0 / 255.0, green: 247.0 / 255.0, blue: 251.0 / 255.0, alpha: 1.0)
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.registerMainWindow(self)
    }
  }
}
