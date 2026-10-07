import 'package:flutter/foundation.dart';

/// A builder or client profile. Wallet-first: the wallet is the identity,
/// the profile only adds how the person is shown. No email or password.
@immutable
class Profile {
  const Profile({
    required this.displayName,
    required this.handle,
    required this.wallet,
    this.bio = '',
  });

  final String displayName;

  /// Lowercase, without the leading `@`.
  final String handle;

  /// The Stellar address the profile belongs to.
  final String wallet;
  final String bio;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    return letters.join().toUpperCase();
  }
}

/// Why a profile could not be saved.
enum ProfileProblem { nameEmpty, nameTooLong, handleInvalid, bioTooLong }

/// In-memory profile for the connected wallet, plus the agents it deployed
/// this session. A Serverpod endpoint replaces the storage later.
class ProfileController extends ChangeNotifier {
  static final _handle = RegExp(r'^[a-z0-9_]{3,20}$');

  Profile? _profile;
  final List<String> _agentIds = [];

  Profile? get profile => _profile;

  /// Ids of the agents deployed from this device, newest first.
  List<String> get agentIds => List.unmodifiable(_agentIds);

  /// The profile for [wallet], or null when it has none.
  Profile? profileFor(String? wallet) =>
      wallet != null && _profile?.wallet == wallet ? _profile : null;

  /// Problems with the given values; empty when they can be saved.
  static Set<ProfileProblem> validate({
    required String displayName,
    required String handle,
    required String bio,
  }) => {
    if (displayName.trim().isEmpty) ProfileProblem.nameEmpty,
    if (displayName.trim().length > 40) ProfileProblem.nameTooLong,
    if (!_handle.hasMatch(handle.trim().toLowerCase().replaceFirst('@', '')))
      ProfileProblem.handleInvalid,
    if (bio.trim().length > 160) ProfileProblem.bioTooLong,
  };

  /// Creates or updates the profile of [wallet]. Throws [ArgumentError] when
  /// [validate] reports a problem.
  void save({
    required String wallet,
    required String displayName,
    required String handle,
    String bio = '',
  }) {
    final problems = validate(
      displayName: displayName,
      handle: handle,
      bio: bio,
    );
    if (problems.isNotEmpty) throw ArgumentError(problems);
    _profile = Profile(
      displayName: displayName.trim(),
      handle: handle.trim().toLowerCase().replaceFirst('@', ''),
      wallet: wallet,
      bio: bio.trim(),
    );
    notifyListeners();
  }

  void addAgent(String id) {
    _agentIds
      ..remove(id)
      ..insert(0, id);
    notifyListeners();
  }

  /// Forgets the profile, e.g. when the wallet disconnects.
  void clear() {
    _profile = null;
    notifyListeners();
  }
}
