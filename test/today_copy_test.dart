import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/dashboard/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blockerStatus: empty is Not set up, off is Paused, else On', () {
    expect(
      blockerStatus(total: 0, enabled: 0, masterOn: true),
      BlockerStatus.notSetUp,
    );
    expect(
      blockerStatus(total: 3, enabled: 3, masterOn: false),
      BlockerStatus.paused,
    );
    expect(
      blockerStatus(total: 3, enabled: 0, masterOn: true),
      BlockerStatus.paused,
    );
    expect(
      blockerStatus(total: 3, enabled: 1, masterOn: true),
      BlockerStatus.on,
    );
  });
}
