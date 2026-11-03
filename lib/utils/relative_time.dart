/// "Just now", "7h ago", "Yesterday", "3d ago" or a short date, for lists of
/// past conversations.
String relativeTime(DateTime then, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final age = current.difference(then);
  if (age.isNegative || age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';

  final today = DateTime(current.year, current.month, current.day);
  final thatDay = DateTime(then.year, then.month, then.day);
  final days = today.difference(thatDay).inDays;
  if (days == 0) return '${age.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final label = '${then.day} ${months[then.month - 1]}';
  return then.year == current.year ? label : '$label ${then.year}';
}
