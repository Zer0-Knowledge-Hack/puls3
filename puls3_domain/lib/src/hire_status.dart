/// The states of a hire. See docs/domain/hire-lifecycle.md.
enum HireStatus {
  requested,
  paid,
  inProgress,
  delivered,
  rated,
  cancelled,
  failed;

  /// Terminal states accept no further event.
  bool get isTerminal => switch (this) {
    HireStatus.rated || HireStatus.cancelled || HireStatus.failed => true,
    _ => false,
  };
}

/// The events that move a hire between states, one per `Hire` method.
enum HireEvent { pay, cancel, start, deliver, fail, rate }
