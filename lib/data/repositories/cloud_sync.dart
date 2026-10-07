import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Sincronização em nuvem com Firestore (Firebase).
///
/// Modo de uso:
/// 1. Crie o projeto no Firebase Console e gere o `firebase_options.dart`
///    (com `flutterfire configure`).
/// 2. `CloudSync.initialize()` é chamado no init do AppState.
/// 3. Toda mutação local chama `syncMeal`/`syncUser`... e lê o espelho.
///
/// Se o Firebase não estiver configurado, o app funciona 100% offline
/// com o [LocalStore] (sem sincronização).
class CloudSync {
  CloudSync._();

  static bool _initialized = false;
  static bool get available => _initialized;

  static String? get _userId => null; // substituir pelo uid do Firebase Auth

  static Future<bool> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: options);
      _initialized = true;
      debugPrint('✅ CloudSync: Firestore conectado.');
    } catch (e) {
      _initialized = false;
      debugPrint('ℹ️ CloudSync: Firebase não configurado — modo offline. ($e)');
    }
    return _initialized;
  }

  static CollectionReference<Map<String, dynamic>>? _col(String name) {
    if (!_initialized || _userId == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(_userId).collection(name);
  }

  static Future<void> syncMeal(Map<String, dynamic> json) async {
    final col = _col('meals');
    if (col == null) return;
    await col.doc(json['id'] as String?).set(json);
  }

  static Future<void> deleteMeal(String id) async {
    final col = _col('meals');
    if (col == null) return;
    await col.doc(id).delete();
  }

  static Future<void> syncUser(Map<String, dynamic> json) async {
    if (!_initialized || _userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('profile')
        .doc('main')
        .set(json);
  }

  static Future<void> syncWorkout(Map<String, dynamic> json) async {
    final col = _col('workouts');
    if (col == null) return;
    await col.doc(json['id'] as String?).set(json);
  }

  static Future<void> syncWeight(Map<String, dynamic> json) async {
    final col = _col('weights');
    if (col == null) return;
    await col.doc(json['date'] as String).set(json);
  }
}

// Gera com `flutterfire configure` e descomente o import.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// Placeholder — substitua pelo arquivo gerado pelo Firebase CLI.
  static FirebaseOptions get currentPlatform => throw UnimplementedError(
        'Firebase não configurado ainda. Execute "flutterfire configure" '
        'e substitua este getter pelos options gerados.',
      );
}