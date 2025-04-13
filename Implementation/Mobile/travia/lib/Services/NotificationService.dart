import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../main.dart';

class NotificationService {
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static void init() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User is signed in, initialize FCM
        await _initializeFCM(user.uid);
      } else {
        _removeFCMListeners();
      }
    });
  }

  static Future<void> _initializeFCM(String currentUserId) async {
    await FirebaseMessaging.instance.requestPermission();

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _setFcmToken(currentUserId: currentUserId, fcmToken: fcmToken);
    }

    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (newFcmToken) async {
        await _setFcmToken(currentUserId: currentUserId, fcmToken: newFcmToken);
      },
    );
  }

  static void _removeFCMListeners() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  static Future<void> removeFcmToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      // Fetch the FCM tokens for the signed-in user
      final response = await supabase.from('users').select('fcm_token').eq('id', userId).single();

      final List<String> tokens = (response['fcm_token'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

      final String? currentToken = await FirebaseMessaging.instance.getToken();

      if (currentToken != null && tokens.contains(currentToken)) {
        // Remove the current token from the list
        tokens.remove(currentToken);

        // Update the user's FCM tokens, removing only the current token
        await supabase.from('users').update({'fcm_token': tokens}).eq('id', userId);
      }
    }
  }

  static Future<void> _setFcmToken({required String currentUserId, required String fcmToken}) async {
    final allUsers = await supabase.from('users').select('id, fcm_token');

    for (var user in allUsers) {
      final List<String> tokens = List<String>.from(user['fcm_token'] ?? []);

      if (tokens.contains(fcmToken) && user['id'] != currentUserId) {
        // Remove this token from any other user
        tokens.remove(fcmToken);
        await supabase.from('users').update({'fcm_token': tokens}).eq('id', user['id']);
      }
    }

    // add the token to the current user
    final response = await supabase.from('users').select('fcm_token').eq('id', currentUserId).single();
    List<String> tokens = (response['fcm_token'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

    if (!tokens.contains(fcmToken)) {
      tokens.add(fcmToken);
      await supabase.from('users').update({'fcm_token': tokens}).eq('id', currentUserId);
    }
  }
}
