#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

HWND FindExistingWindow() {
  HWND hwnd = nullptr;
  while ((hwnd = FindWindowEx(nullptr, hwnd, L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr)) != nullptr) {
    wchar_t window_title[256];
    GetWindowText(hwnd, window_title, sizeof(window_title) / sizeof(wchar_t));
    std::wstring title(window_title);
    // Look for L"JA Sync" (to match "JA Sync  v1.0.0" or "JA Sync Manager") or L"ja_sync"
    if (title.find(L"JA Sync") != std::wstring::npos || title.find(L"ja_sync") != std::wstring::npos) {
      return hwnd;
    }
  }
  return nullptr;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Prevent running multiple instances
  HANDLE mutex = CreateMutex(nullptr, true, L"Local\\JA_Sync_SingleInstance_Mutex");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND hwnd = FindExistingWindow();
    if (hwnd) {
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      } else if (!IsWindowVisible(hwnd)) {
        ShowWindow(hwnd, SW_SHOW);
      }
      SetForegroundWindow(hwnd);
    }
    if (mutex != nullptr) {
      CloseHandle(mutex);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ja_sync", origin, size)) {
    if (mutex != nullptr) {
      CloseHandle(mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (mutex != nullptr) {
    CloseHandle(mutex);
  }
  return EXIT_SUCCESS;
}
