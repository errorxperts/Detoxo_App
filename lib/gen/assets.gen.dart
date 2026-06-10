// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsConfigGen {
  const $AssetsConfigGen();

  /// File path: assets/config/initial_config.json
  String get initialConfig => 'assets/config/initial_config.json';

  /// File path: assets/config/platforms_config.json
  String get platformsConfig => 'assets/config/platforms_config.json';

  /// List of all assets
  List<String> get values => [initialConfig, platformsConfig];
}

class $AssetsContentGen {
  const $AssetsContentGen();

  /// File path: assets/content/curious_emojis.json
  String get curiousEmojis => 'assets/content/curious_emojis.json';

  /// File path: assets/content/daily_limit_emoji_bands.json
  String get dailyLimitEmojiBands =>
      'assets/content/daily_limit_emoji_bands.json';

  /// File path: assets/content/mindful_timer_quotes.json
  String get mindfulTimerQuotes => 'assets/content/mindful_timer_quotes.json';

  /// File path: assets/content/pause_countdown_cooldown_emojis.json
  String get pauseCountdownCooldownEmojis =>
      'assets/content/pause_countdown_cooldown_emojis.json';

  /// File path: assets/content/pause_countdown_pause_emojis.json
  String get pauseCountdownPauseEmojis =>
      'assets/content/pause_countdown_pause_emojis.json';

  /// File path: assets/content/pause_emojis.json
  String get pauseEmojis => 'assets/content/pause_emojis.json';

  /// List of all assets
  List<String> get values => [
    curiousEmojis,
    dailyLimitEmojiBands,
    mindfulTimerQuotes,
    pauseCountdownCooldownEmojis,
    pauseCountdownPauseEmojis,
    pauseEmojis,
  ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/detox_logo_no_bg.png
  AssetGenImage get detoxLogoNoBg =>
      const AssetGenImage('assets/images/detox_logo_no_bg.png');

  /// File path: assets/images/detoxo_logo.png
  AssetGenImage get detoxoLogo =>
      const AssetGenImage('assets/images/detoxo_logo.png');

  /// List of all assets
  List<AssetGenImage> get values => [detoxLogoNoBg, detoxoLogo];
}

class Assets {
  const Assets._();

  static const $AssetsConfigGen config = $AssetsConfigGen();
  static const $AssetsContentGen content = $AssetsContentGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
