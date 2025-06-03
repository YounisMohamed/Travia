import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

// Provider for the UserPresenceService
final userPresenceServiceProvider = Provider<UserPresenceService>((ref) {
  final service = UserPresenceService();
  return service;
});

class UserPresenceService {
  Timer? _heartbeatTimer;
  StreamSubscription<fb.User?>? _authSubscription;
  AppLifecycleListener? _lifecycleListener;
  String? _currentUserId;

  // Initialize the service
  void initialize() {
    // Listen for auth state changes from Firebase
    _authSubscription = fb.FirebaseAuth.instance.authStateChanges().listen((fb.User? user) {
      if (user != null) {
        _currentUserId = user.uid;
        _setUserOnline(true);
        _startHeartbeat();
        _setupLifecycleListener();
      } else {
        _setUserOffline();
        _disposeLifecycleListener();
        _currentUserId = null;
      }
    });

    // Check if user is already signed in when initializing
    final currentUser = fb.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _currentUserId = currentUser.uid;
      _setUserOnline(true);
      _startHeartbeat();
      _setupLifecycleListener();
    }
  }

  // Set up app lifecycle listener to detect when app goes to background/foreground
  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        if (_currentUserId == null) return;

        switch (state) {
          case AppLifecycleState.resumed:
            // App comes to foreground
            _setUserOnline(true);
            break;
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
          case AppLifecycleState.inactive:
            // App goes to background or is closed
            _setUserOfflineAndUpdateLastActive();
            break;
          default:
            break;
        }
      },
      // handle app termination
      onDetach: () {
        if (_currentUserId != null) {
          _setUserOfflineAndUpdateLastActive();
        }
      },
    );
  }

  // Combined method to ensure both operations are completed
  Future<void> _setUserOfflineAndUpdateLastActive() async {
    if (_currentUserId == null) return;

    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // Perform a single update with both values
      await supabase.from('conversation_participants').update({
        'is_online': false,
        'last_active_at': now,
      }).eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error updating offline status and last active: $e');
    }
  }

  // Start heartbeat to update last_active_at periodically
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (_currentUserId != null) {
        _updateLastActive();
      }
    });
  }

  // Update last_active_at timestamp in database
  Future<void> _updateLastActive() async {
    if (_currentUserId == null) return;

    try {
      await supabase.from('conversation_participants').update({
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error updating last_active: $e');
    }
  }

  // Set user online/offline status
  Future<void> _setUserOnline(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await supabase.from('conversation_participants').update({
        'is_online': isOnline,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Set user offline before app completely closes
  Future<void> _setUserOffline() async {
    if (_currentUserId == null) return;

    try {
      await supabase.from('conversation_participants').update({
        'is_online': false,
      }).eq('user_id', _currentUserId!);
    } catch (e) {
      debugPrint('Error setting user offline: $e');
    }
  }

  void dispose() {
    _setUserOfflineAndUpdateLastActive();
    _disposeLifecycleListener();
    _authSubscription?.cancel();
  }

  void _disposeLifecycleListener() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}

final userOnlineStatusProvider = StreamProvider.family<bool, String>((ref, userId) {
  return supabase.from('conversation_participants').stream(primaryKey: ['conversation_id', 'user_id']).eq('user_id', userId).map((data) {
        if (data.isEmpty) return false;
        return data.first['is_online'] ?? false;
      });
});

// Provider to get user's last active time
final userLastActiveProvider = FutureProvider.family<DateTime?, String>((ref, userId) async {
  final response = await supabase.from('conversation_participants').select('last_active_at').eq('user_id', userId).order('last_active_at', ascending: false).limit(1).maybeSingle();

  if (response == null || response['last_active_at'] == null) return null;

  return DateTime.parse(response['last_active_at']);
});
