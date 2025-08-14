import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bass_flutter_platform_interface.dart';

/// An implementation of [BassFlutterPlatform] that uses method channels.
class MethodChannelBassFlutter extends BassFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bass_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
