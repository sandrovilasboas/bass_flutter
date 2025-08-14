import 'package:flutter_test/flutter_test.dart';
import 'package:bass_flutter/bass_flutter.dart';
import 'package:bass_flutter/bass_flutter_platform_interface.dart';
import 'package:bass_flutter/bass_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBassFlutterPlatform
    with MockPlatformInterfaceMixin
    implements BassFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BassFlutterPlatform initialPlatform = BassFlutterPlatform.instance;

  test('$MethodChannelBassFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBassFlutter>());
  });

  test('getPlatformVersion', () async {
    BassFlutter bassFlutterPlugin = BassFlutter();
    MockBassFlutterPlatform fakePlatform = MockBassFlutterPlatform();
    BassFlutterPlatform.instance = fakePlatform;

    expect(await bassFlutterPlugin.getPlatformVersion(), '42');
  });
}
