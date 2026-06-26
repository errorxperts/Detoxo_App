import 'package:flutter/material.dart';

/// A predefined, popular "time-wasting" website surfaced as a one-tap chip.
///
/// [domains] lists every host the site is reachable on: [primaryDomain] is the
/// one stored as the user's blocklist entry, and the rest are aliases that the
/// cubit folds into the native payload (a `DOMAIN` match on `youtube.com` already
/// covers `m.`/`www.` subdomains, but a cross-registrable alias like `youtu.be`
/// needs its own rule).
class PopularSite {
  const PopularSite({
    required this.id,
    required this.name,
    required this.domains,
    required this.icon,
    required this.brandColor,
  });

  final String id;
  final String name;
  final List<String> domains;
  final IconData icon;
  final int brandColor;

  String get primaryDomain => domains.first;
}

/// The curated catalogue shown under "Popular time-wasting websites".
abstract final class PopularSites {
  static const List<PopularSite> all = [
    PopularSite(
      id: 'youtube',
      name: 'YouTube',
      domains: ['youtube.com', 'youtu.be'],
      icon: Icons.smart_display_outlined,
      brandColor: 0xFFFF0033,
    ),
    PopularSite(
      id: 'instagram',
      name: 'Instagram',
      domains: ['instagram.com'],
      icon: Icons.camera_alt_outlined,
      brandColor: 0xFFE1306C,
    ),
    PopularSite(
      id: 'facebook',
      name: 'Facebook',
      domains: ['facebook.com', 'fb.com'],
      icon: Icons.facebook,
      brandColor: 0xFF1877F2,
    ),
    PopularSite(
      id: 'x',
      name: 'X (Twitter)',
      domains: ['x.com', 'twitter.com'],
      icon: Icons.alternate_email,
      brandColor: 0xFF1DA1F2,
    ),
    PopularSite(
      id: 'reddit',
      name: 'Reddit',
      domains: ['reddit.com'],
      icon: Icons.forum_outlined,
      brandColor: 0xFFFF4500,
    ),
    PopularSite(
      id: 'netflix',
      name: 'Netflix',
      domains: ['netflix.com'],
      icon: Icons.movie_outlined,
      brandColor: 0xFFE50914,
    ),
    PopularSite(
      id: 'prime',
      name: 'Prime Video',
      domains: ['primevideo.com'],
      icon: Icons.movie_creation_outlined,
      brandColor: 0xFF00A8E1,
    ),
    PopularSite(
      id: 'disney',
      name: 'Disney+',
      domains: ['disneyplus.com'],
      icon: Icons.movie_filter_outlined,
      brandColor: 0xFF113CCF,
    ),
    PopularSite(
      id: 'twitch',
      name: 'Twitch',
      domains: ['twitch.tv'],
      icon: Icons.videogame_asset_outlined,
      brandColor: 0xFF9146FF,
    ),
    PopularSite(
      id: 'tiktok',
      name: 'TikTok',
      domains: ['tiktok.com'],
      icon: Icons.music_note_outlined,
      brandColor: 0xFF69C9D0,
    ),
    PopularSite(
      id: 'pinterest',
      name: 'Pinterest',
      domains: ['pinterest.com'],
      icon: Icons.push_pin_outlined,
      brandColor: 0xFFE60023,
    ),
    PopularSite(
      id: 'snapchat',
      name: 'Snapchat',
      domains: ['snapchat.com'],
      icon: Icons.chat_bubble_outline,
      brandColor: 0xFFFFC500,
    ),
    PopularSite(
      id: 'linkedin',
      name: 'LinkedIn',
      domains: ['linkedin.com'],
      icon: Icons.work_outline,
      brandColor: 0xFF0A66C2,
    ),
    PopularSite(
      id: 'quora',
      name: 'Quora',
      domains: ['quora.com'],
      icon: Icons.help_outline,
      brandColor: 0xFFB92B27,
    ),
    PopularSite(
      id: 'tumblr',
      name: 'Tumblr',
      domains: ['tumblr.com'],
      icon: Icons.text_fields,
      brandColor: 0xFF36465D,
    ),
  ];

  /// The site whose primary domain equals [primaryDomain], or null.
  static PopularSite? byPrimaryDomain(String primaryDomain) {
    for (final s in all) {
      if (s.primaryDomain == primaryDomain) return s;
    }
    return null;
  }

  /// Alias domains (everything past the primary) for a stored popular entry.
  static List<String> aliasesFor(String primaryDomain) {
    final site = byPrimaryDomain(primaryDomain);
    if (site == null || site.domains.length < 2) return const [];
    return site.domains.sublist(1);
  }
}
