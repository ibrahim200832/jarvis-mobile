import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? city;
  final String? country;

  LocationResult({required this.latitude, required this.longitude, this.city, this.country});
}

/// Determines the current GPS position and reverse-geocodes it to a
/// city/country name, replacing the `opencage` phone-number-to-location
/// guesswork in the desktop app with a real, accurate GPS reading.
class LocationService {
  Future<LocationResult> current() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Standortberechtigung wurde verweigert.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Standortdienste sind deaktiviert.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String? city;
    String? country;
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        city = placemarks.first.locality;
        country = placemarks.first.country;
      }
    } catch (_) {
      // Reverse geocoding is best-effort; coordinates alone are still useful.
    }

    return LocationResult(latitude: pos.latitude, longitude: pos.longitude, city: city, country: country);
  }
}
