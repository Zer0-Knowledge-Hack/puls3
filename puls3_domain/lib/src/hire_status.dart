/// The states of a hire. They mirror the ERC-8183 escrow job 1:1 (ADR-0005
/// D6). See docs/domain/hire-lifecycle.md.
enum HireStatus {
  open,
  funded,
  submitted,
  completed,
  rejected,
  expired;

  /// Terminal states accept no further event.
  bool get isTerminal => switch (this) {
    HireStatus.completed || HireStatus.rejected || HireStatus.expired => true,
    _ => false,
  };
}

/// The events that move a hire between states, one per `Hire` method. Each is
/// a confirmed ERC-8183 escrow transition.
enum HireEvent { fund, submit, complete, reject, expire }

/// The agent runtime's progress on a funded hire. It is hire data, not a hire
/// state: the hire stays `funded` while the agent works (ADR-0005 D6).
enum RuntimeStatus { queued, running, failed }
