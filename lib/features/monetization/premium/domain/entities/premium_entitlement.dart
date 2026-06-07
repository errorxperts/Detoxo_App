import 'package:equatable/equatable.dart';

/// Premium entitlement, resolved from billing or a local dev-unlock.
class PremiumEntitlement extends Equatable {
  const PremiumEntitlement({this.isPremium = false, this.activePlans = const []});

  final bool isPremium;
  final List<String> activePlans;

  @override
  List<Object?> get props => [isPremium, activePlans];
}
