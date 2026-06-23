import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// PIN-lock configuration. Custom PINs are stored as a salted SHA-256 hash
/// (never plaintext); Date/Time PINs are derived from the clock and store no
/// secret at all. The retry ladder escalates lockouts on repeated failures.
class PinConfig extends Equatable {
  const PinConfig({
    this.type = PinType.none,
    this.secretHash = '',
    this.salt = '',
    this.secretLength = 0,
    this.scopes = const {},
    this.verifiedEmail = '',
    this.retryCount = 0,
    this.lockedUntil,
    this.biometricEnabled = false,
  });

  factory PinConfig.fromJson(Map<String, dynamic> json) => PinConfig(
        type: PinType.fromWire(json['type'] as String?),
        secretHash: json['secretHash'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        secretLength: json['secretLength'] as int? ?? 0,
        scopes: ((json['scopes'] as List?)?.cast<String>() ?? const [])
            .map(PinScope.fromWire)
            .toSet(),
        verifiedEmail: json['verifiedEmail'] as String? ?? '',
        retryCount: json['retryCount'] as int? ?? 0,
        lockedUntil: json['lockedUntil'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['lockedUntil'] as int),
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      );

  final PinType type;

  /// Salted SHA-256 hash of a custom PIN; empty for Date/Time/None.
  final String secretHash;

  /// Random salt used to derive [secretHash]; empty for Date/Time/None.
  final String salt;

  /// Digit count of a custom PIN, kept so the lock screen can render the entry
  /// dots and auto-submit without ever holding the secret.
  final int secretLength;

  final Set<PinScope> scopes;
  final String verifiedEmail;
  final int retryCount;
  final DateTime? lockedUntil;
  final bool biometricEnabled;

  bool get isConfigured => type != PinType.none;
  bool get isLockedOut =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  bool guards(PinScope scope) => scopes.contains(scope);

  PinConfig copyWith({
    PinType? type,
    String? secretHash,
    String? salt,
    int? secretLength,
    Set<PinScope>? scopes,
    String? verifiedEmail,
    int? retryCount,
    DateTime? lockedUntil,
    bool clearLockout = false,
    bool? biometricEnabled,
  }) =>
      PinConfig(
        type: type ?? this.type,
        secretHash: secretHash ?? this.secretHash,
        salt: salt ?? this.salt,
        secretLength: secretLength ?? this.secretLength,
        scopes: scopes ?? this.scopes,
        verifiedEmail: verifiedEmail ?? this.verifiedEmail,
        retryCount: retryCount ?? this.retryCount,
        lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      );

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'secretHash': secretHash,
        'salt': salt,
        'secretLength': secretLength,
        'scopes': scopes.map((e) => e.wire).toList(),
        'verifiedEmail': verifiedEmail,
        'retryCount': retryCount,
        'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
        'biometricEnabled': biometricEnabled,
      };

  @override
  List<Object?> get props => [
        type,
        secretHash,
        salt,
        secretLength,
        scopes,
        verifiedEmail,
        retryCount,
        lockedUntil,
        biometricEnabled,
      ];
}

/// The escalating lockout ladder (verified thresholds from the reference app).
abstract final class PinLockoutPolicy {
  /// Returns the lockout duration for a given (post-increment) retry count, or
  /// null for "no lockout".
  static Duration? lockoutFor(int retryCount) {
    if (retryCount <= 5) return null;
    if (retryCount <= 8) return const Duration(seconds: 30);
    if (retryCount <= 10) return const Duration(minutes: 5);
    if (retryCount <= 15) return const Duration(hours: 1);
    if (retryCount <= 20) return const Duration(hours: 4);
    return const Duration(hours: 24);
  }
}
