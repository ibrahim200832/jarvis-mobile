/// Normalizes free-text/voice input into QR-code payload data, replacing
/// the `pyqrcode` based QR generator from the desktop app. Actual rendering
/// happens via qr_flutter's QrImageView widget in the UI layer.
class QrService {
  String normalize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw Exception('Kein Text für den QR-Code angegeben.');
    }
    return trimmed;
  }
}
