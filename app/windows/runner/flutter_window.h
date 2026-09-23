#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <shellapi.h>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Windows System Media Transport Controls (SMTC) & Hardware Media Key Channel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> smtc_channel_;
  void SetupSmtcChannel();
  void HandleAppCommand(short app_command);

  // Windows System Tray (Shell_NotifyIcon) & Background Close Control
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> tray_channel_;
  NOTIFYICONDATAW nid_ = {};
  bool is_tray_installed_ = false;
  bool minimize_to_tray_ = true;

  void SetupTray();
  void RemoveTray();
  void UpdateTrayTooltip(const std::wstring& tooltip);
  void ShowTrayContextMenu();

  // Windows Floating Lyric & Window TopMost Channel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> floating_lyric_channel_;
  bool is_always_on_top_ = false;
  bool is_click_through_ = false;
  void SetupFloatingLyricChannel();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
