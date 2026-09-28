import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSWindowDelegate {
  private var statusItem: NSStatusItem?
  private var trayChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?
  private var smtcChannel: FlutterMethodChannel?
  private weak var mainWindow: NSWindow?
  private var minimizeToTray: Bool = true

  private var targetWindow: NSWindow? {
    return mainWindow ?? NSApp.windows.first(where: { $0 is MainFlutterWindow }) ?? NSApp.windows.first
  }

  func registerMainWindow(_ window: NSWindow) {
    self.mainWindow = window
    window.delegate = self
    setupChannels()
    setupTray()
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = targetWindow {
      self.mainWindow = window
      window.delegate = self
    }

    setupTray()
    setupChannels()
  }

  // 点击 Dock 栏图标时若窗口隐藏则重新唤醒并居前
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showMainWindow()
    return true
  }

  override func applicationDidBecomeActive(_ notification: Notification) {
    if let window = targetWindow, !window.isVisible {
      showMainWindow()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 若开启最小化到托盘，则关闭窗口后不终止应用
    return !minimizeToTray
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // 拦截 macOS 窗口关闭按钮 (红灯)，转为隐藏到托盘
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if minimizeToTray {
      sender.orderOut(nil)
      return false
    }
    return true
  }

  private func setupChannels() {
    guard let controller = targetWindow?.contentViewController as? FlutterViewController else {
      return
    }

    if trayChannel != nil { return }

    // 托盘通道
    trayChannel = FlutterMethodChannel(
      name: "com.kline.mellow_music/tray",
      binaryMessenger: controller.engine.binaryMessenger
    )
    trayChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "init":
        if let args = call.arguments as? [String: Any],
           let minToTray = args["minimizeToTray"] as? Bool {
          self.minimizeToTray = minToTray
        }
        self.setupTray()
        result(true)
      case "setMinimizeToTray":
        if let args = call.arguments as? [String: Any],
           let minToTray = args["enabled"] as? Bool {
          self.minimizeToTray = minToTray
        }
        result(true)
      case "updateTrayTooltip":
        if let args = call.arguments as? [String: Any],
           let tip = args["tooltip"] as? String {
          self.statusItem?.button?.toolTip = tip
        }
        result(true)
      case "showWindow":
        self.showMainWindow()
        result(true)
      case "hideWindow":
        self.targetWindow?.orderOut(nil)
        result(true)
      case "minimizeWindow":
        self.targetWindow?.miniaturize(nil)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 窗口控制通道
    windowChannel = FlutterMethodChannel(
      name: "com.kline.mellow_music/window",
      binaryMessenger: controller.engine.binaryMessenger
    )
    windowChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "minimize":
        self.targetWindow?.miniaturize(nil)
        result(true)
      case "hide":
        self.targetWindow?.orderOut(nil)
        result(true)
      case "show":
        self.showMainWindow()
        result(true)
      case "close":
        if self.minimizeToTray {
          self.targetWindow?.orderOut(nil)
        } else {
          self.targetWindow?.close()
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 原生多媒体控制通道绑定
    smtcChannel = FlutterMethodChannel(
      name: "com.kline.mellow_music/smtc",
      binaryMessenger: controller.engine.binaryMessenger
    )
  }

  private func setupTray() {
    if statusItem == nil {
      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
    guard let button = statusItem?.button else { return }

    // 优先从 Assets 资产库加载 StatusBarIcon（支持 1x/2x 高清矢量）
    var iconImage: NSImage? = NSImage(named: "StatusBarIcon") ?? NSImage(named: "status_bar_icon")

    // 若资产库未就绪，使用 macOS 原生 SF Symbols 权威系统音符图标保底 (macOS 11+)
    if iconImage == nil {
      if #available(macOS 11.0, *) {
        iconImage = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Mellow Music")
      }
    }

    if let image = iconImage {
      image.size = NSSize(width: 18, height: 18)
      image.isTemplate = true // 自动根据 macOS 菜单栏深浅与按压状态适配颜色
      button.image = image
      button.imagePosition = .imageOnly
    } else {
      button.title = "♫"
    }
    button.toolTip = "Mellow Music · 润音"

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "显示主界面", action: #selector(onShowMainWindow), keyEquivalent: "s"))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "播放 / 暂停", action: #selector(onTogglePlay), keyEquivalent: " "))
    menu.addItem(NSMenuItem(title: "上一首", action: #selector(onPrevTrack), keyEquivalent: "["))
    menu.addItem(NSMenuItem(title: "下一首", action: #selector(onNextTrack), keyEquivalent: "]"))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "隐藏到托盘", action: #selector(onHideMainWindow), keyEquivalent: "h"))
    menu.addItem(NSMenuItem(title: "退出 Mellow Music", action: #selector(onQuitApp), keyEquivalent: "q"))

    statusItem?.menu = menu
  }

  private func showMainWindow() {
    guard let window = targetWindow else { return }
    window.setIsVisible(true)
    window.makeKeyAndOrderFront(nil)
    window.deminiaturize(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func onShowMainWindow() {
    showMainWindow()
  }

  @objc private func onHideMainWindow() {
    targetWindow?.orderOut(nil)
  }

  @objc private func onTogglePlay() {
    smtcChannel?.invokeMethod("onButtonPressed", arguments: ["button": "toggleplay"])
  }

  @objc private func onPrevTrack() {
    smtcChannel?.invokeMethod("onButtonPressed", arguments: ["button": "previous"])
  }

  @objc private func onNextTrack() {
    smtcChannel?.invokeMethod("onButtonPressed", arguments: ["button": "next"])
  }

  @objc private func onQuitApp() {
    minimizeToTray = false
    NSApp.terminate(nil)
  }
}
