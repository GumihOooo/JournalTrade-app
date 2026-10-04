/// One watchlist row (P2-04, DATABASE.md §8).
class WatchlistItem {
  const WatchlistItem({
    required this.id,
    required this.userId,
    required this.instrument,
    this.sortOrder,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String instrument;
  final int? sortOrder;
  final DateTime? createdAt;
}

/// Duplicate instrument for the same user (P2-04.04) — surfaced as a
/// friendly failure, not a raw AppwriteException.
class DuplicateInstrumentFailure implements Exception {
  const DuplicateInstrumentFailure(this.instrument);
  final String instrument;

  @override
  String toString() => 'DuplicateInstrumentFailure: $instrument';
}
