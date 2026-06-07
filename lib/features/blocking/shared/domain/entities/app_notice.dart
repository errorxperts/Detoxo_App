import 'package:equatable/equatable.dart';

/// An in-app notification / nudge from initial_config.
class AppNotice extends Equatable {
  const AppNotice({
    required this.id,
    required this.title,
    required this.description,
    required this.cta,
    required this.action,
    this.url = '',
    this.dismissible = true,
  });

  final String id;
  final String title;
  final String description;
  final String cta;
  final String action;
  final String url;
  final bool dismissible;

  @override
  List<Object?> get props => [id, title, description, cta, action, url];
}
