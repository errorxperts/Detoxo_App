import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/app_domain_catalog.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/popular_site.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_source.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/utils/domain_validator.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockSettingsRepo extends Mock implements SettingsRepository {}

class _MockAppBlockRepo extends Mock implements AppBlockRepository {}

class _MockStatsRepo extends Mock implements WebBlockStatsRepository {}

class _MockEngine extends Mock implements EngineRepository {}

void main() {
  group('DomainValidator.normalize', () {
    test('strips scheme, www, path, query and port', () {
      expect(
        DomainValidator.normalize('https://www.YouTube.com/watch?v=1'),
        'youtube.com',
      );
      expect(
        DomainValidator.normalize('http://example.com:8080'),
        'example.com',
      );
      expect(
        DomainValidator.normalize('  Sub.Example.CO.uk  '),
        'sub.example.co.uk',
      );
    });

    test('accepts bare and subdomains', () {
      expect(DomainValidator.normalize('example.com'), 'example.com');
      expect(
        DomainValidator.normalize('news.ycombinator.com'),
        'news.ycombinator.com',
      );
    });

    test('rejects empty, spaces, scheme-only and single-label hosts', () {
      expect(DomainValidator.normalize(''), isNull);
      expect(DomainValidator.normalize('not a domain'), isNull);
      expect(DomainValidator.normalize('https://'), isNull);
      expect(DomainValidator.normalize('localhost'), isNull);
      expect(DomainValidator.normalize('com'), isNull);
    });

    test('isDuplicate matches an existing pattern', () {
      const entries = [WebBlockEntry(pattern: 'youtube.com')];
      expect(DomainValidator.isDuplicate('youtube.com', entries), isTrue);
      expect(DomainValidator.isDuplicate('vimeo.com', entries), isFalse);
    });
  });

  group('PopularSites & AppDomainCatalog', () {
    test('byPrimaryDomain and aliasesFor resolve the catalogue', () {
      final yt = PopularSites.byPrimaryDomain('youtube.com');
      expect(yt?.name, 'YouTube');
      expect(PopularSites.aliasesFor('youtube.com'), contains('youtu.be'));
      expect(PopularSites.aliasesFor('reddit.com'), isEmpty);
      expect(PopularSites.byPrimaryDomain('nope.com'), isNull);
    });

    test('app package maps to its content domains', () {
      expect(
        AppDomainCatalog.domainsFor('com.google.android.youtube'),
        contains('youtube.com'),
      );
      expect(AppDomainCatalog.domainsFor('com.unknown.app'), isEmpty);
    });
  });

  group('WebBlockStats', () {
    test('focus minutes use the 30s-per-block heuristic', () {
      expect(const WebBlockStats().focusMinutesSaved, 0);
      expect(const WebBlockStats(totalBlocked: 2).focusMinutesSaved, 1);
      expect(const WebBlockStats(totalBlocked: 10).focusMinutesSaved, 5);
    });
  });

  group('WebBlockState derived getters', () {
    const entries = [
      WebBlockEntry(
        pattern: 'youtube.com',
        displayName: 'YouTube',
        source: WebBlockSource.popular,
      ),
      WebBlockEntry(pattern: 'news.example.com'),
    ];

    test('activePopularIds reflects which popular primaries are present', () {
      const state = WebBlockState(entries: entries);
      expect(state.activePopularIds, contains('youtube'));
      expect(state.activePopularIds, isNot(contains('reddit')));
    });

    test('visibleEntries filters by host or display name', () {
      expect(
        const WebBlockState(
          entries: entries,
          query: 'tube',
        ).visibleEntries.map((e) => e.pattern),
        ['youtube.com'],
      );
      expect(
        const WebBlockState(
          entries: entries,
          query: 'example',
        ).visibleEntries.map((e) => e.pattern),
        ['news.example.com'],
      );
      expect(const WebBlockState(entries: entries).visibleEntries.length, 2);
    });
  });

  group('WebBlockCubit', () {
    late _MockWebRepo webRepo;
    late _MockSettingsRepo settingsRepo;
    late _MockAppBlockRepo appBlockRepo;
    late _MockStatsRepo statsRepo;
    late _MockEngine engine;

    setUpAll(() {
      registerFallbackValue(const AppSettings());
      registerFallbackValue(<WebBlockEntry>[]);
    });

    setUp(() {
      webRepo = _MockWebRepo();
      settingsRepo = _MockSettingsRepo();
      appBlockRepo = _MockAppBlockRepo();
      statsRepo = _MockStatsRepo();
      engine = _MockEngine();
      when(() => webRepo.save(any())).thenAnswer((_) async {});
      when(
        () => settingsRepo.load(),
      ).thenAnswer((_) async => const AppSettings());
      when(
        () => appBlockRepo.load(),
      ).thenAnswer((_) async => <AppBlockEntry>[]);
      when(() => engine.pushWebBlocklist(any())).thenAnswer((_) async {});
    });

    WebBlockCubit build() =>
        WebBlockCubit(webRepo, settingsRepo, appBlockRepo, statsRepo, engine);

    List<Map<String, dynamic>> lastPushed() {
      final json =
          verify(() => engine.pushWebBlocklist(captureAny())).captured.last
              as String;
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    }

    blocTest<WebBlockCubit, WebBlockState>(
      'addCustom normalizes, persists and pushes the entry',
      build: build,
      act: (c) => c.addCustom('https://www.Example.com/x'),
      verify: (c) {
        expect(c.state.entries.map((e) => e.pattern), ['example.com']);
        verify(() => webRepo.save(any())).called(1);
        expect(lastPushed().map((m) => m['pattern']), contains('example.com'));
      },
    );

    blocTest<WebBlockCubit, WebBlockState>(
      'addCustom rejects an invalid domain and pushes nothing',
      build: build,
      act: (c) => c.addCustom('not a domain'),
      verify: (c) {
        expect(c.state.entries, isEmpty);
        expect(c.state.error, isNotNull);
        verifyNever(() => engine.pushWebBlocklist(any()));
      },
    );

    blocTest<WebBlockCubit, WebBlockState>(
      'togglePopular adds the primary domain and pushes its aliases too',
      build: build,
      act: (c) => c.togglePopular(PopularSites.byPrimaryDomain('youtube.com')!),
      verify: (c) {
        expect(c.state.entries.single.pattern, 'youtube.com');
        final pushed = lastPushed().map((m) => m['pattern']).toList();
        expect(pushed, containsAll(['youtube.com', 'youtu.be']));
      },
    );
  });
}
