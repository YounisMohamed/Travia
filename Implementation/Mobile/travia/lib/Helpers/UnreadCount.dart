class UnreadCountHelper {
  final String conversationId;
  final DateTime lastReadAt;

  const UnreadCountHelper({
    required this.conversationId,
    required this.lastReadAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnreadCountHelper && runtimeType == other.runtimeType && conversationId == other.conversationId && lastReadAt == other.lastReadAt;

  @override
  int get hashCode => conversationId.hashCode ^ lastReadAt.hashCode;
}
