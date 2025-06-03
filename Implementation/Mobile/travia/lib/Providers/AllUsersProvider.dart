import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Auth/AuthMethods.dart';
import '../Classes/UserSupabase.dart';
import '../main.dart';

final usersProvider = StreamProvider<List<UserModel>>((ref) async* {
  // Watch the Firebase auth state
  final authStateAsync = ref.watch(firebaseAuthProvider);

  // Return an empty list while loading auth state
  if (authStateAsync.isLoading) {
    yield [];
    return;
  }

  // If there's an error or user is null (logged out), yield empty list
  if (authStateAsync.hasError || authStateAsync.value == null) {
    yield [];
    return;
  }

  try {
    // Create a stream that can be cancelled
    final controller = StreamController<List<UserModel>>();

    // Set up the Supabase stream for users table
    final subscription = supabase.from('users').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) => data.map((json) => UserModel.fromJson(json)).toList()).listen(
          (users) {
            controller.add(users);
          },
          onError: (error) {
            print('Supabase users stream error: $error');
            controller.addError(error);
          },
        );

    // Make sure to close the subscription when the provider is disposed
    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    // Yield users from the controller
    await for (final users in controller.stream) {
      yield users;
    }
  } catch (e) {
    print('Users provider error: $e');
    rethrow;
  }
});
