// lib/src/ffi/bass_constants.dart

/// Flags para BASS_StreamCreateFile
class BassStreamFlags {
  static const int DEFAULT = 0;

  /// Faz prescan para obter duração exata
  static const int PRESCAN = 0x20000;

  /// Libera o stream automaticamente ao final
  static const int AUTOFREE = 0x40000;

  /// Decodificação apenas (sem reprodução)
  static const int DECODE = 0x200000;

  /// Áudio como 32-bit float
  static const int FLOAT = 0x100;

  /// Loop automático
  static const int LOOP = 0x4;

  /// Usa UTF-16 (Windows)
  static const int UNICODE = 0x80000000;
}

/// Status retornados por BASS_ChannelIsActive
class BassChannelStatus {
  static const int STOPPED = 0;
  static const int PLAYING = 1;
  static const int STALLED = 2;
  static const int PAUSED = 3;
}
