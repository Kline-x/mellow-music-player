#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
