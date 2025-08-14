import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'bass_ffi_loader.dart';

class BassInitializer {
  static bool init({int device = -1, int freq = 44100, int flags = 0}) {
    final bass = BassLoader.instance;

    final result = bass.BASS_Init(
      device, // device (-1 = default)
      freq, // frequency (44100 = CD Quality)
      flags, // flags (0 = default)
      nullptr,
      nullptr,
    );

    final success = result != 0;
    if (!success) {
      debugPrint('BASS_Init failed');
    }

    return success;
  }
}
