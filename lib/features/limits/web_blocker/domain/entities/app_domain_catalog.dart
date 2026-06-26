/// Maps a blocked app's package name to the website domain(s) that serve the
/// same content. This powers the "Block sites for blocked apps" tile: the cubit
/// reads the existing App Blocker list and derives a tiny web blocklist from it,
/// so the package list itself never has to cross the channel.
///
/// `DOMAIN` matching on `youtube.com` already covers `m.`/`www.` subdomains, so
/// only the registrable domain (plus genuine cross-domain aliases like
/// `youtu.be`) is listed here.
abstract final class AppDomainCatalog {
  static const Map<String, List<String>> map = {
    // Video / streaming
    'com.google.android.youtube': ['youtube.com', 'youtu.be'],
    'com.google.android.apps.youtube.music': ['music.youtube.com'],
    'com.netflix.mediaclient': ['netflix.com'],
    'com.amazon.avod.thirdpartyclient': ['primevideo.com'],
    'com.disney.disneyplus': ['disneyplus.com'],
    'tv.twitch.android.app': ['twitch.tv'],
    // Social
    'com.instagram.android': ['instagram.com'],
    'com.facebook.katana': ['facebook.com', 'fb.com'],
    'com.facebook.lite': ['facebook.com', 'fb.com'],
    'com.twitter.android': ['x.com', 'twitter.com'],
    'com.reddit.frontpage': ['reddit.com'],
    'com.snapchat.android': ['snapchat.com'],
    'com.pinterest': ['pinterest.com'],
    'com.linkedin.android': ['linkedin.com'],
    'com.quora.android': ['quora.com'],
    'com.tumblr': ['tumblr.com'],
    // Short-form video
    'com.zhiliaoapp.musically': ['tiktok.com'],
    'com.ss.android.ugc.trill': ['tiktok.com'],
  };

  static List<String> domainsFor(String packageName) =>
      map[packageName] ?? const [];
}
