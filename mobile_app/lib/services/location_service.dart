import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationService {
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return null;
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address
      String address = "Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 5));
          
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            // More detailed address
            address = '${place.name ?? place.street}, ${place.subLocality ?? ''}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}';
            address = address.replaceAll(', ,', ','); // Clean up empty parts
          }
        } catch (e) {
          print('Geocoding error: $e');
        }
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }
}
