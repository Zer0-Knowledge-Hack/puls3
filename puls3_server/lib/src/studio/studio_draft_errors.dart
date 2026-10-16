/// No draft has this id. The message never includes a manifest.
final class StudioDraftMissing implements Exception {
  const StudioDraftMissing();

  @override
  String toString() => 'StudioDraftMissing';
}

/// The draft exists and belongs to another wallet. The message never
/// includes a manifest.
final class StudioDraftNotOwned implements Exception {
  const StudioDraftNotOwned();

  @override
  String toString() => 'StudioDraftNotOwned';
}

/// The caller saved over a revision that is no longer current.
final class StudioDraftRevisionConflict implements Exception {
  const StudioDraftRevisionConflict();

  @override
  String toString() => 'StudioDraftRevisionConflict';
}
