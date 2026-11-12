abstract interface class ReserveDismissal {
  static const period = Duration(days: 30);

  Future<DateTime?> dismissedUntil();

  Future<void> dismiss(DateTime now);
}
