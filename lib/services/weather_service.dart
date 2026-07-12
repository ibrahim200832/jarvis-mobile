import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherResult {
  final String description;
  final double tempCelsius;
  final String city;

  WeatherResult({required this.description, required this.tempCelsius, required this.city});
}

/// Fetches current weather from OpenWeatherMap, given free-text city name or
/// lat/lon coordinates. Requires a free API key from
/// https://openweathermap.org configured in Settings.
class WeatherService {
  Future<WeatherResult> byCity(String apiKey, String city) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'q': city,
      'appid': apiKey,
      'units': 'metric',
      'lang': 'de',
    });
    return _fetch(uri);
  }

  Future<WeatherResult> byCoordinates(String apiKey, double lat, double lon) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'appid': apiKey,
      'units': 'metric',
      'lang': 'de',
    });
    return _fetch(uri);
  }

  Future<WeatherResult> _fetch(Uri uri) async {
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Wetter konnte nicht geladen werden (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final weatherList = json['weather'] as List;
    final description = (weatherList.first as Map<String, dynamic>)['description'] as String;
    final temp = (json['main'] as Map<String, dynamic>)['temp'] as num;
    final city = json['name'] as String? ?? '';
    return WeatherResult(description: description, tempCelsius: temp.toDouble(), city: city);
  }
}
