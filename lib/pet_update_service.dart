import 'package:flutter/material.dart';

class PetUpdateService {
  static final PetUpdateService _instance = PetUpdateService._internal();
  factory PetUpdateService() => _instance;
  PetUpdateService._internal();

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyPetUpdated() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void dispose() {
    _listeners.clear();
  }
}
