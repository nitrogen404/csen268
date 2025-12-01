import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('user_settings');

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      _collection.doc(uid);

  Future<AppSettings> getSettings(String uid) async {
    final snap = await _docRef(uid).get();
    if (!snap.exists) {
      const defaults = AppSettings();
      await _docRef(uid).set(defaults.toMap(), SetOptions(merge: true));
      return defaults;
    }
    return AppSettings.fromMap(snap.data());
  }

  Stream<AppSettings> watchSettings(String uid) {
    return _docRef(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return const AppSettings();
      }
      return AppSettings.fromMap(doc.data());
    });
  }

  Future<void> updateSettings(String uid, AppSettings settings) async {
    await _docRef(uid).set(
      settings.toMap(),
      SetOptions(merge: true),
    );
  }
}


