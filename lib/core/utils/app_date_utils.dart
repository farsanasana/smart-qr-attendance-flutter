/// Lightweight date, time, and duration helpers without external locale dependencies.
class AppDateUtils {
  AppDateUtils._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Returns `yyyy-MM-dd` for local date matching and SQLite filtering.
  static String toDateKey(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats as `Thu, 12 Nov 2026`.
  static String formatFullDate(DateTime dt) {
    final local = dt.toLocal();
    final weekday = _weekdays[local.weekday - 1];
    final month = _months[local.month - 1];
    final day = local.day.toString().padLeft(2, '0');
    return '$weekday, $day $month ${local.year}';
  }

  /// Formats as `12 Nov 2026`.
  static String formatShortDate(DateTime dt) {
    final local = dt.toLocal();
    final month = _months[local.month - 1];
    final day = local.day.toString().padLeft(2, '0');
    return '$day $month ${local.year}';
  }

  /// Formats as `09:15 AM`.
  static String formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$min $period';
  }

  /// Formats as `09:15:30 AM`.
  static String formatTimeWithSeconds(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$min:$sec $period';
  }

  /// Formats `yyyy-MM-dd` string to `12 Nov 2026`.
  static String formatDateKey(String dateKey) {
    final parsed = DateTime.tryParse(dateKey);
    if (parsed == null) return dateKey;
    return formatShortDate(parsed);
  }

  /// Calculates working duration between check-in and check-out (or now if active).
  static Duration calculateWorkingDuration({
    required DateTime? checkIn,
    DateTime? checkOut,
    DateTime? fallbackEnd,
  }) {
    if (checkIn == null) return Duration.zero;
    final end = checkOut ?? fallbackEnd ?? DateTime.now();
    if (end.isBefore(checkIn)) return Duration.zero;
    return end.difference(checkIn);
  }

  /// Formats a duration as `8h 15m` or `0h 45m`.
  static String formatDuration(Duration duration) {
    if (duration.inMinutes <= 0) return '0h 00m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// Formats countdown seconds as `04:59`.
  static String formatCountdown(Duration remaining) {
    if (remaining.isNegative || remaining.inSeconds <= 0) return '00:00';
    final mins = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = remaining.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mins:$secs';
    }
    return '$mins:$secs';
  }
}

