import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Authentacation/AuthMethods.dart';

final authProvider = FutureProvider<User?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final userExists = await checkIfUserExists(user.uid);
  print("INDEED $userExists");
  return userExists ? user : null;
});
