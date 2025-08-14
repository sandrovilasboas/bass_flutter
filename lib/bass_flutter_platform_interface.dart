import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bass_flutter_method_channel.dart';

abstract class BassFlutterPlatform extends PlatformInterface {
  /// Constructs a BassFlutterPlatform.
  BassFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static BassFlutterPlatform _instance = MethodChannelBassFlutter();

  /// The default instance of [BassFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelBassFlutter].
  static BassFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BassFlutterPlatform] when
  /// they register themselves.
  static set instance(BassFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
