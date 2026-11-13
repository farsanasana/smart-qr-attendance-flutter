import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure({
    required this.type,
    required this.message,
  });

  final LocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

class CapturedCoordinates {
  const CapturedCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// Service handling GPS permission checks and coordinate capture via geolocator.
class LocationService {
  Future<CapturedCoordinates> captureCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        type: LocationFailureType.serviceDisabled,
        message:
            'GPS location services are turned off. Please enable Location Services to verify your attendance.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(
          type: LocationFailureType.permissionDenied,
          message:
              'Location permission was denied. Grant location access to record your attendance coordinates.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        type: LocationFailureType.permissionDeniedForever,
        message:
            'Location permission is permanently denied. Open App Settings to allow location access.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return CapturedCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return CapturedCoordinates(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
        );
      }
      throw const LocationFailure(
        type: LocationFailureType.unavailable,
        message:
            'GPS signal timed out. Move near an open window or outdoors and try again.',
      );
    } catch (e) {
      throw LocationFailure(
        type: LocationFailureType.unavailable,
        message: 'Unable to determine GPS location. ($e)',
      );
    }
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

