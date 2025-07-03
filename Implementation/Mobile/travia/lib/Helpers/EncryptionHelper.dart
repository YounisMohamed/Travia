import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionHelper {
  static String APP_SALT = dotenv.env['APP_SALT'] ?? "";
  static String generateConversationKey(String conversationId) {
    var bytes = utf8.encode('$conversationId-$APP_SALT');
    var digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  static String encryptContent(String plainText, String conversationId) {
    try {
      print("SALT FOR TESTING ${APP_SALT}");
      final encryptionKey = generateConversationKey(conversationId);
      final key = Key.fromUtf8(encryptionKey);
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key));

      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('Encryption error: $e');
      return plainText;
    }
  }

  static String decryptContent(String encryptedText, String conversationId) {
    try {
      if (!encryptedText.contains(':')) {
        return encryptedText;
      }

      final parts = encryptedText.split(':');
      if (parts.length != 2) return encryptedText;

      final encryptionKey = generateConversationKey(conversationId);
      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      final key = Key.fromUtf8(encryptionKey);
      final encrypter = Encrypter(AES(key));

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return encryptedText;
    }
  }
}
