#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#define WM_TRAY_ICON (WM_USER + 101)
#define IDM_TRAY_SHOW 1001
#define IDM_TRAY_PLAY_PAUSE 1002
#define IDM_TRAY_PREV 1003
#define IDM_TRAY_NEXT 1004
#define IDM_TRAY_FLOATING_LYRIC 1006
#define IDM_TRAY_TOPMOST 1007
#define IDM_TRAY_EXIT 1005

namespace {
std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, str.data(), static_cast<int>(str.size()), nullptr, 0);
  std::wstring out(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.data(), static_cast<int>(str.size()), out.data(), size);
  return out;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetupSmtcChannel();
  SetupTray();
  SetupFloatingLyricChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTray();
  floating_lyric_channel_ = nullptr;
  tray_channel_ = nullptr;
  smtc_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetupSmtcChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;

  smtc_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.kline.mellow_music/smtc",
      &flutter::StandardMethodCodec::GetInstance());

  smtc_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "init") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "updateMetadata") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "updatePlaybackState") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "updateTimeline") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "clear") {
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::HandleAppCommand(short app_command) {
  if (!smtc_channel_) return;

  std::string action = "";
  switch (app_command) {
    case APPCOMMAND_MEDIA_PLAY_PAUSE:
      action = "toggleplay";
      break;
    case APPCOMMAND_MEDIA_PLAY:
      action = "play";
      break;
    case APPCOMMAND_MEDIA_PAUSE:
      action = "pause";
      break;
    case APPCOMMAND_MEDIA_NEXTTRACK:
      action = "next";
      break;
    case APPCOMMAND_MEDIA_PREVIOUSTRACK:
      action = "previous";
      break;
    case APPCOMMAND_MEDIA_STOP:
      action = "stop";
      break;
  }

  if (!action.empty()) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("button")] = flutter::EncodableValue(action);
    smtc_channel_->InvokeMethod("onButtonPressed",
                                std::make_unique<flutter::EncodableValue>(args));
  }
}

void FlutterWindow::SetupTray() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;

  HWND hwnd = GetHandle();
  if (!hwnd) return;

  memset(&nid_, 0, sizeof(NOTIFYICONDATAW));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = hwnd;
  nid_.uID = 1;
  nid_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid_.uCallbackMessage = WM_TRAY_ICON;
  nid_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(nid_.szTip, L"Mellow 音乐播放器");
  Shell_NotifyIconW(NIM_ADD, &nid_);
  is_tray_installed_ = true;

  tray_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.kline.mellow_music/tray",
      &flutter::StandardMethodCodec::GetInstance());

  tray_channel_->SetMethodCallHandler(
      [this, hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "init") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("minimizeToTray"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<bool>(&it->second)) {
                this->minimize_to_tray_ = *val;
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "setMinimizeToTray") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("enabled"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<bool>(&it->second)) {
                this->minimize_to_tray_ = *val;
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "updateTrayTooltip") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("tooltip"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<std::string>(&it->second)) {
                this->UpdateTrayTooltip(Utf8ToWide(*val));
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "showWindow") {
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "hideWindow") {
          ShowWindow(hwnd, SW_HIDE);
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::RemoveTray() {
  if (is_tray_installed_) {
    Shell_NotifyIconW(NIM_DELETE, &nid_);
    is_tray_installed_ = false;
  }
}

void FlutterWindow::UpdateTrayTooltip(const std::wstring& tooltip) {
  if (!is_tray_installed_) return;
  wcsncpy_s(nid_.szTip, tooltip.c_str(), _countof(nid_.szTip) - 1);
  nid_.szTip[_countof(nid_.szTip) - 1] = L'\0';
  nid_.uFlags = NIF_TIP;
  Shell_NotifyIconW(NIM_MODIFY, &nid_);
}

void FlutterWindow::ShowTrayContextMenu() {
  POINT pt;
  GetCursorPos(&pt);
  HMENU hMenu = CreatePopupMenu();
  if (!hMenu) return;

  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_SHOW, L"显示主界面");
  AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_PLAY_PAUSE, L"播放 / 暂停");
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_PREV, L"上一首");
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_NEXT, L"下一首");
  AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_FLOATING_LYRIC, L"桌面歌词 开/关 (Ctrl+D)");
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_TOPMOST, is_always_on_top_ ? L"取消窗口置顶" : L"窗口始终置顶");
  AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(hMenu, MF_STRING, IDM_TRAY_EXIT, L"退出程序");

  HWND hwnd = GetHandle();
  SetForegroundWindow(hwnd);

  int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                           pt.x, pt.y, 0, hwnd, nullptr);
  DestroyMenu(hMenu);

  if (cmd == IDM_TRAY_SHOW) {
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
  } else if (cmd == IDM_TRAY_PLAY_PAUSE) {
    if (smtc_channel_) {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("button")] = flutter::EncodableValue("toggleplay");
      smtc_channel_->InvokeMethod("onButtonPressed",
                                  std::make_unique<flutter::EncodableValue>(args));
    }
  } else if (cmd == IDM_TRAY_PREV) {
    if (smtc_channel_) {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("button")] = flutter::EncodableValue("previous");
      smtc_channel_->InvokeMethod("onButtonPressed",
                                  std::make_unique<flutter::EncodableValue>(args));
    }
  } else if (cmd == IDM_TRAY_NEXT) {
    if (smtc_channel_) {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("button")] = flutter::EncodableValue("next");
      smtc_channel_->InvokeMethod("onButtonPressed",
                                  std::make_unique<flutter::EncodableValue>(args));
    }
  } else if (cmd == IDM_TRAY_FLOATING_LYRIC) {
    if (floating_lyric_channel_) {
      floating_lyric_channel_->InvokeMethod("toggleFloatingLyric", nullptr);
    }
  } else if (cmd == IDM_TRAY_TOPMOST) {
    is_always_on_top_ = !is_always_on_top_;
    SetWindowPos(hwnd, is_always_on_top_ ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    if (floating_lyric_channel_) {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("alwaysOnTop")] = flutter::EncodableValue(is_always_on_top_);
      floating_lyric_channel_->InvokeMethod("onAlwaysOnTopChanged",
                                            std::make_unique<flutter::EncodableValue>(args));
    }
  } else if (cmd == IDM_TRAY_EXIT) {
    minimize_to_tray_ = false;
    RemoveTray();
    DestroyWindow(hwnd);
  }
}

void FlutterWindow::SetupFloatingLyricChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;

  HWND hwnd = GetHandle();
  if (!hwnd) return;

  floating_lyric_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.kline.mellow_music/floating_lyric",
      &flutter::StandardMethodCodec::GetInstance());

  floating_lyric_channel_->SetMethodCallHandler(
      [this, hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setAlwaysOnTop") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("alwaysOnTop"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<bool>(&it->second)) {
                this->is_always_on_top_ = *val;
                SetWindowPos(hwnd, *val ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                             SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "setClickThrough") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("clickThrough"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<bool>(&it->second)) {
                this->is_click_through_ = *val;
                LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
                if (*val) {
                  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TRANSPARENT | WS_EX_LAYERED);
                } else {
                  SetWindowLong(hwnd, GWL_EXSTYLE, exStyle & ~WS_EX_TRANSPARENT);
                }
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "isAlwaysOnTop") {
          result->Success(flutter::EncodableValue(this->is_always_on_top_));
        } else if (call.method_name() == "isClickThrough") {
          result->Success(flutter::EncodableValue(this->is_click_through_));
        } else if (call.method_name() == "updateLyric") {
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_APPCOMMAND: {
      short cmd = GET_APPCOMMAND_LPARAM(lparam);
      HandleAppCommand(cmd);
      return TRUE;
    }
    case WM_CLOSE: {
      if (minimize_to_tray_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    }
    case WM_TRAY_ICON: {
      switch (lparam) {
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          return 0;
        case WM_RBUTTONUP:
          ShowTrayContextMenu();
          return 0;
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
