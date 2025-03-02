import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';

import '../Classes/Notification.dart';

class NotificationCacheService {
  static const String _notificationsBoxName = 'notifications';
  static const String _metadataBoxName = 'notifications_metadata';

  late final Box<Map> _notificationsBox;
  late final Box<String> _metadataBox;
  bool _isInitialized = false;

  final _notificationsSubject = BehaviorSubject<List<NotificationModel>>();

  NotificationCacheService() {
    // Initialize immediately when created
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive boxes
      _notificationsBox = await Hive.openBox<Map>(_notificationsBoxName);
      _metadataBox = await Hive.openBox<String>(_metadataBoxName);
      _isInitialized = true;

      // Load initial cached data
      _loadCachedNotifications();
    } catch (e) {
      print('Error initializing cache service: $e');
      _isInitialized = false;
    }
  }

  // Stream of cached notifications combined with new ones
  Stream<List<NotificationModel>> get notificationsStream => _notificationsSubject.stream;

  // Load initial cached notifications
  void _loadCachedNotifications() {
    if (!_isInitialized) return;

    final cachedNotifications = _notificationsBox.values.map((map) => NotificationModel.fromMap(Map<String, dynamic>.from(map))).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notificationsSubject.add(cachedNotifications);
  }

  // Add or update notifications in cache
  Future<void> cacheNotifications(List<NotificationModel> notifications) async {
    if (!_isInitialized) await _init();

    try {
      // Convert notifications to Map and store in Hive
      for (final notification in notifications) {
        await _notificationsBox.put(
          notification.id,
          notification.toMap(),
        );
      }

      // Update last cached timestamp
      await _metadataBox.put('last_updated', DateTime.now().toIso8601String());

      // Update the stream with all current notifications
      final allNotifications = _notificationsBox.values.map((map) => NotificationModel.fromMap(Map<String, dynamic>.from(map))).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notificationsSubject.add(allNotifications);
    } catch (e) {
      print('Error caching notifications: $e');
    }
  }

  // Get cached notifications
  List<NotificationModel> getCachedNotifications() {
    if (!_isInitialized) return [];

    return _notificationsBox.values.map((map) => NotificationModel.fromMap(Map<String, dynamic>.from(map))).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get last updated timestamp
  DateTime? getLastUpdated() {
    if (!_isInitialized) return null;
    final timestamp = _metadataBox.get('last_updated');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Clear cache
  Future<void> clearCache() async {
    if (!_isInitialized) await _init();

    await _notificationsBox.clear();
    await _metadataBox.clear();
    _notificationsSubject.add([]);
  }

  // Close boxes and stream
  Future<void> dispose() async {
    if (!_isInitialized) return;

    await _notificationsBox.close();
    await _metadataBox.close();
    await _notificationsSubject.close();
    _isInitialized = false;
  }
}
