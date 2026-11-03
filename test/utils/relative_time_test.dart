import 'package:cryonis/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 2, 15, 30);

  test('recent times are in minutes and hours', () {
    expect(relativeTime(now, now: now), 'Just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(relativeTime(now.subtract(const Duration(hours: 7)), now: now), '7h ago');
  });

  test('a clock set in the future does not produce nonsense', () {
    expect(relativeTime(now.add(const Duration(hours: 2)), now: now), 'Just now');
  });

  test('older times use calendar days', () {
    expect(relativeTime(DateTime(2026, 11, 1, 23, 50), now: now), 'Yesterday');
    expect(relativeTime(DateTime(2026, 10, 30, 9), now: now), '3d ago');
  });

  test('a week or more shows the date, with the year only when it differs', () {
    expect(relativeTime(DateTime(2026, 10, 12), now: now), '12 Oct');
    expect(relativeTime(DateTime(2025, 12, 25), now: now), '25 Dec 2025');
  });
}
