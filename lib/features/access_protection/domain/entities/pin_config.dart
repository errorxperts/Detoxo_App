import 'package:equatable/equatable.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';

/// PIN-lock configuration. The secret is stored encrypted (secure storage); the
/// retry ladder escalates lockouts on repeated failures.
class PinConfig extends Equatable {
  const PinConfig({
    this.type = PinType.none,
    this.secret = '',
    this.scopes = const {},
    this.verifiedEmail = '',
    this.retryCount = 0,
    this.lockedUntil,
    this.biometricEnabled = false,
  });

  final PinType type;
  final String secret;
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
    String? secret,
    Set<PinScope>? scopes,
    String? verifiedEmail,
    int? retryCount,
    DateTime? lockedUntil,
    bool clearLockout = false,
    bool? biometricEnabled,
  }) =>
      PinConfig(
        type: type ?? this.type,
        secret: secret ?? this.secret,
        scopes: scopes ?? this.scopes,
        verifiedEmail: verifiedEmail ?? this.verifiedEmail,
        retryCount: retryCount ?? this.retryCount,
        lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      );

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'secret': secret,
        'scopes': scopes.map((e) => e.wire).toList(),
        'verifiedEmail': verifiedEmail,
        'retryCount': retryCount,
        'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
        'biometricEnabled': biometricEnabled,
      };

  factory PinConfig.fromJson(Map<String, dynamic> json) => PinConfig(
        type: PinType.fromWire(json['type'] as String?),
        secret: json['secret'] as String? ?? '',
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

  @override
  List<Object?> get props =>
      [type, secret, scopes, verifiedEmail, retryCount, lockedUntil, biometricEnabled];
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
