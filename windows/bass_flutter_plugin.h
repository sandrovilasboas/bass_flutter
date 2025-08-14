#ifndef FLUTTER_PLUGIN_BASS_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_BASS_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace bass_flutter {

class BassFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  BassFlutterPlugin();

  virtual ~BassFlutterPlugin();

  // Disallow copy and assign.
  BassFlutterPlugin(const BassFlutterPlugin&) = delete;
  BassFlutterPlugin& operator=(const BassFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace bass_flutter

#endif  // FLUTTER_PLUGIN_BASS_FLUTTER_PLUGIN_H_
