/// Utility to format decimal hours into human-readable clock time
/// Example: 0.7h -> 42m, 1.5h -> 1h 30m, 0.0h -> 0m, 2.0h -> 2h
String formatHoursToReadableTime(double hours) {
  if (hours <= 0) return "0m";
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;

  if (h == 0) {
    return "${m}m";
  } else if (m == 0) {
    return "${h}h";
  } else {
    return "${h}h ${m}m";
  }
}
