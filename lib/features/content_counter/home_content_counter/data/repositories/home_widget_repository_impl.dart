import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/content_count.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart';
import 'package:home_widget/home_widget.dart';

/// Drives the home-screen widget via the `home_widget` package, with the native
/// command channel as the source of truth + fallback. The widget itself renders
/// from `ContentCounterStore` (native), so these calls only trigger a refresh /
/// pin; `home_widget` failing (e.g. plugin unavailable) never breaks counting.
class HomeWidgetRepositoryImpl implements HomeWidgetRepository {
  HomeWidgetRepositoryImpl(this._channel);

  final EngineChannel _channel;

  static const String _widgetName = 'ContentCounterWidgetProvider';
  static const String _qualifiedName =
      'com.errorxperts.detoxo.widget.ContentCounterWidgetProvider';

  @override
  Future<bool> pin() async {
    if (!PlatformCapabilities.supportsBlockingEngine) return false;
    try {
      await HomeWidget.requestPinWidget(
        name: _widgetName,
        androidName: _widgetName,
        qualifiedAndroidName: _qualifiedName,
      );
      return true;
    } catch (_) {
      // Plugin unavailable / launcher refused — fall back to the native request.
      return _channel.pinContentWidget();
    }
  }

  @override
  Future<void> pushSnapshot(ContentCount count) async {
    if (!PlatformCapabilities.supportsBlockingEngine) return;
    try {
      await HomeWidget.saveWidgetData<int>('cc_today', count.today);
      await HomeWidget.saveWidgetData<int>('cc_total', count.total);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
        qualifiedAndroidName: _qualifiedName,
      );
    } catch (_) {
      // home_widget unavailable — the native render below is the real source.
    }
    await _channel.refreshContentWidget();
  }

  @override
  Future<void> refresh() => _channel.refreshContentWidget();
}
