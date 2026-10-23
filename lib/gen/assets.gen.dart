/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart' as _svg;
import 'package:vector_graphics/vector_graphics.dart' as _vg;

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

  /// File path: assets/content/motivational_quotes.json
  String get motivationalQuotes => 'assets/content/motivational_quotes.json';

  /// List of all assets
  List<String> get values => [motivationalQuotes];
}

class $AssetsFontsGen {
  const $AssetsFontsGen();

  /// File path: assets/fonts/OFL.txt
  String get ofl => 'assets/fonts/OFL.txt';

  /// List of all assets
  List<String> get values => [ofl];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// Directory path: assets/images/icons
  $AssetsImagesIconsGen get icons => const $AssetsImagesIconsGen();
}

class $AssetsSvgGen {
  const $AssetsSvgGen();

  /// File path: assets/svg/check.svg
  SvgGenImage get check => const SvgGenImage('assets/svg/check.svg');

  /// File path: assets/svg/chevron-right.svg
  SvgGenImage get chevronRight =>
      const SvgGenImage('assets/svg/chevron-right.svg');

  /// File path: assets/svg/chevrons-right.svg
  SvgGenImage get chevronsRight =>
      const SvgGenImage('assets/svg/chevrons-right.svg');

  /// File path: assets/svg/flame.svg
  SvgGenImage get flame => const SvgGenImage('assets/svg/flame.svg');

  /// File path: assets/svg/play-circle.svg
  SvgGenImage get playCircle => const SvgGenImage('assets/svg/play-circle.svg');

  /// File path: assets/svg/sidebar.svg
  SvgGenImage get sidebar => const SvgGenImage('assets/svg/sidebar.svg');

  /// List of all assets
  List<SvgGenImage> get values => [
    check,
    chevronRight,
    chevronsRight,
    flame,
    playCircle,
    sidebar,
  ];
}

class $AssetsImagesIconsGen {
  const $AssetsImagesIconsGen();

  /// File path: assets/images/icons/detoxo_logo.png
  AssetGenImage get detoxoLogo =>
      const AssetGenImage('assets/images/icons/detoxo_logo.png');

  /// File path: assets/images/icons/icon-app-blocker.webp
  AssetGenImage get iconAppBlocker =>
      const AssetGenImage('assets/images/icons/icon-app-blocker.webp');

  /// File path: assets/images/icons/icon-block-all.webp
  AssetGenImage get iconBlockAll =>
      const AssetGenImage('assets/images/icons/icon-block-all.webp');

  /// File path: assets/images/icons/icon-blocker-rules.webp
  AssetGenImage get iconBlockerRules =>
      const AssetGenImage('assets/images/icons/icon-blocker-rules.webp');

  /// File path: assets/images/icons/icon-conscious.webp
  AssetGenImage get iconConscious =>
      const AssetGenImage('assets/images/icons/icon-conscious.webp');

  /// File path: assets/images/icons/icon-one-reel.webp
  AssetGenImage get iconOneReel =>
      const AssetGenImage('assets/images/icons/icon-one-reel.webp');

  /// File path: assets/images/icons/icon-pause.webp
  AssetGenImage get iconPause =>
      const AssetGenImage('assets/images/icons/icon-pause.webp');

  /// File path: assets/images/icons/icon-reel-count.webp
  AssetGenImage get iconReelCount =>
      const AssetGenImage('assets/images/icons/icon-reel-count.webp');

  /// File path: assets/images/icons/icon-web-blocker.webp
  AssetGenImage get iconWebBlocker =>
      const AssetGenImage('assets/images/icons/icon-web-blocker.webp');

  /// List of all assets
  List<AssetGenImage> get values => [
    detoxoLogo,
    iconAppBlocker,
    iconBlockAll,
    iconBlockerRules,
    iconConscious,
    iconOneReel,
    iconPause,
    iconReelCount,
    iconWebBlocker,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsConfigGen config = $AssetsConfigGen();
  static const $AssetsContentGen content = $AssetsContentGen();
  static const $AssetsFontsGen fonts = $AssetsFontsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsSvgGen svg = $AssetsSvgGen();
}

class AssetGenImage {
  const AssetGenImage(this._assetName, {this.size, this.flavors = const {}});

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

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

class SvgGenImage {
  const SvgGenImage(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = false;

  const SvgGenImage.vec(this._assetName, {this.size, this.flavors = const {}})
    : _isVecFormat = true;

  final String _assetName;
  final Size? size;
  final Set<String> flavors;
  final bool _isVecFormat;

  _svg.SvgPicture svg({
    Key? key,
    bool matchTextDirection = false,
    AssetBundle? bundle,
    String? package,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    bool allowDrawingOutsideViewBox = false,
    WidgetBuilder? placeholderBuilder,
    String? semanticsLabel,
    bool excludeFromSemantics = false,
    _svg.SvgTheme? theme,
    ColorFilter? colorFilter,
    Clip clipBehavior = Clip.hardEdge,
    @deprecated Color? color,
    @deprecated BlendMode colorBlendMode = BlendMode.srcIn,
    @deprecated bool cacheColorFilter = false,
  }) {
    final _svg.BytesLoader loader;
    if (_isVecFormat) {
      loader = _vg.AssetBytesLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
      );
    } else {
      loader = _svg.SvgAssetLoader(
        _assetName,
        assetBundle: bundle,
        packageName: package,
        theme: theme,
      );
    }
    return _svg.SvgPicture(
      loader,
      key: key,
      matchTextDirection: matchTextDirection,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      allowDrawingOutsideViewBox: allowDrawingOutsideViewBox,
      placeholderBuilder: placeholderBuilder,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter:
          colorFilter ??
          (color == null ? null : ColorFilter.mode(color, colorBlendMode)),
      clipBehavior: clipBehavior,
      cacheColorFilter: cacheColorFilter,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
