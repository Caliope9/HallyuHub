import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/screens/drops_screen.dart';
import 'package:hallyuhub/src/screens/fancams_screen.dart';
import 'package:hallyuhub/src/services/local_drop_service.dart';
import 'package:hallyuhub/src/services/local_fancam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingFancamService extends LocalFancamService {
  const _CapturingFancamService();

  static FancamFeedMode? lastFeedMode;

  @override
  Future<List<Fancam>> restoreFancams({
    int limit = 80,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    FancamFeedMode feedMode = FancamFeedMode.forYou,
  }) async {
    lastFeedMode = feedMode;
    return const [];
  }
}

class _CapturingDropService extends LocalDropService {
  const _CapturingDropService();

  static DropFeedMode? lastFeedMode;

  @override
  Future<List<DropClip>> restoreDrops({
    int limit = 80,
    int offset = 0,
    String? authorId,
    bool onlyCurrentUser = false,
    DropFeedMode feedMode = DropFeedMode.forYou,
  }) async {
    lastFeedMode = feedMode;
    return const [];
  }
}

void main() {
  setUp(() {
    _CapturingFancamService.lastFeedMode = null;
    _CapturingDropService.lastFeedMode = null;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('la entrada desde Home puede abrir Fancams en Más virales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FancamsScreen(
          fancamService: _CapturingFancamService(),
          initialMode: FancamFeedMode.viral,
          showBackButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_CapturingFancamService.lastFeedMode, FancamFeedMode.viral);
    expect(find.text('Más virales'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
  });

  testWidgets('la entrada desde Home puede abrir Drops en Más virales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DropsScreen(
          dropService: _CapturingDropService(),
          initialMode: DropFeedMode.viral,
          showBackButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_CapturingDropService.lastFeedMode, DropFeedMode.viral);
    expect(find.text('Más virales'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
  });

  testWidgets('las entradas normales conservan Para ti por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FancamsScreen(fancamService: _CapturingFancamService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(_CapturingFancamService.lastFeedMode, FancamFeedMode.forYou);

    await tester.pumpWidget(
      const MaterialApp(
        home: DropsScreen(dropService: _CapturingDropService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(_CapturingDropService.lastFeedMode, DropFeedMode.forYou);
  });

  testWidgets('la flecha de entrada desde Home vuelve a la pantalla anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const FancamsScreen(showBackButton: true),
              ),
            ),
            child: const Text('Home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(FancamsScreen), findsNothing);
  });
}
