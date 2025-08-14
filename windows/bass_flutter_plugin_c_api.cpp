#include "include/bass_flutter/bass_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "bass_flutter_plugin.h"

void BassFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  bass_flutter::BassFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
