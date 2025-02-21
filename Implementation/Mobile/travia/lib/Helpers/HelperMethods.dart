String timeAgo(DateTime utcDateTime) {
  // Convert UTC DateTime to local timezone
  final localDateTime = utcDateTime.toLocal();
  final now = DateTime.now(); // This is already in local time
  final difference = now.difference(localDateTime);

  if (difference.inSeconds < 60) {
    return 'Just Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}

String formatCount(int count) {
  if (count < 1000) {
    return count.toString();
  } else if (count < 1000000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else if (count >= 1000000 && count < 1000000000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else {
    return '${(count / 1000000000000).toStringAsFixed(1)}B';
  }
}
