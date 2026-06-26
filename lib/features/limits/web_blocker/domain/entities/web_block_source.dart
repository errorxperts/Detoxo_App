/// Where a website blocklist entry originated. Drives the row affordances in the
/// UI (a custom entry can be edited; popular / app-derived entries show a source
/// pill instead) and lets analytics attribute blocks.
enum WebBlockSource {
  custom('CUSTOM'),
  popular('POPULAR'),
  adult('ADULT'),
  appDerived('APP_DERIVED');

  const WebBlockSource(this.wire);

  final String wire;

  static WebBlockSource fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => WebBlockSource.custom,
  );
}
