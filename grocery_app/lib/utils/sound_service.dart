import 'package:audioplayers/audioplayers.dart';
import '../database/database_helper.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _enabled = true;

  static Future<void> init() async {
    final val = await DatabaseHelper().getSetting('sound_on_sale');
    _enabled = val != 'false';
  }

  static Future<void> playSaleSound() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/cash_register.wav'));
    } catch (_) {}
  }

  static void setEnabled(bool val) {
    _enabled = val;
  }

  static bool get isEnabled => _enabled;
}
