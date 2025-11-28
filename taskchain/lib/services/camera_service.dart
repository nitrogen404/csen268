import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  static const _kPrefsKey = 'profile_photo_path';
  static final ValueNotifier<String?> profileImageNotifier = ValueNotifier<String?>(null);
  final ImagePicker _picker = ImagePicker();

  /// Launches the device camera, saves the picked image to app documents
  /// directory and persists the saved path in SharedPreferences.
  Future<String?> takePictureAndSave() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    } catch (e) {
      return Future.error(e);
    }

    if (picked == null) return null;

    final bytes = await picked.readAsBytes();

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File('${dir.path}/$fileName');
    await target.writeAsBytes(bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, target.path);

    // notify listeners about the new saved path
    profileImageNotifier.value = target.path;

    return target.path;
  }

  /// Pick an existing image from gallery and save it (same persistence as camera).
  Future<String?> pickFromGalleryAndSave() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      return Future.error(e);
    }

    if (picked == null) return null;

    final bytes = await picked.readAsBytes();

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File('${dir.path}/$fileName');
    await target.writeAsBytes(bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, target.path);

    // notify listeners about the new saved path
    profileImageNotifier.value = target.path;

    return target.path;
  }

  /// Returns persisted profile image path if available.
  Future<String?> getSavedProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefsKey);
  }

  /// Clears saved profile image.
  Future<void> clearSavedProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kPrefsKey);
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await prefs.remove(_kPrefsKey);
    // notify listeners that image was cleared
    profileImageNotifier.value = null;
  }
}
