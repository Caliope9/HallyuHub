import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hallyuhub/src/services/hally_feature_tip_service.dart';
import 'package:hallyuhub/src/widgets/hally_feature_tip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HallyFeatureTipService.clearSessionDismissalsForTesting();
  });

  testWidgets('the contextual tip appears as a compact floating popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HallyFeatureTip(
            featureId: 'artists_intro',
            title: 'Descubrí artistas con Hally 💜',
            message: 'Buscá grupos y artistas.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Descubrí artistas con Hally 💜'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hally-tip-popup-artists_intro')),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(HallyFeatureTip)), Size.zero);
  });

  testWidgets('the floating help does not block the screen behind it', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('Pantalla'),
                ),
              ),
              const HallyFeatureTip(
                featureId: 'artists_intro',
                title: 'Artistas',
                message: 'Buscá grupos y artistas.',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pantalla'));
    expect(tapped, isTrue);
    expect(
      find.byKey(const ValueKey('hally-tip-popup-artists_intro')),
      findsOneWidget,
    );
  });

  testWidgets('Entendido avoids repeating the same help in one session', (
    tester,
  ) async {
    const tip = HallyFeatureTip(
      featureId: 'communities_intro',
      title: 'Encontrá tu comunidad 💜',
      message: 'Unite a comunidades.',
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: tip)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('hally-tip-understood-communities_intro')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Encontrá tu comunidad 💜'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: tip)));
    await tester.pumpAndSettle();
    expect(find.text('Encontrá tu comunidad 💜'), findsNothing);

    HallyFeatureTipService.clearSessionDismissalsForTesting();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: tip)));
    await tester.pumpAndSettle();
    expect(find.text('Encontrá tu comunidad 💜'), findsOneWidget);
  });

  testWidgets(
    'opting out disables only that tip and reset preserves other settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'hallyuhub.feature-tip.disabled.artists_intro': true,
        'user.private_profile': true,
        'auth.session': 'test-session',
      });
      const tip = HallyFeatureTip(
        featureId: 'artists_intro',
        title: 'Artistas',
        message: 'Explorá artistas.',
      );
      const otherTip = HallyFeatureTip(
        featureId: 'messages_intro',
        title: 'Mensajes privados 💌',
        message: 'Tus preferencias siguen aplicándose.',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Column(children: [tip, otherTip])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Artistas'), findsNothing);
      expect(find.text('Mensajes privados 💌'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('hally-tip-disable-messages_intro')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mensajes privados 💌'), findsNothing);

      await const HallyFeatureTipService().resetAll();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('user.private_profile'), isTrue);
      expect(preferences.getString('auth.session'), 'test-session');
      expect(
        preferences.getBool('hallyuhub.feature-tip.disabled.artists_intro'),
        isNull,
      );
      expect(
        preferences.getBool('hallyuhub.feature-tip.disabled.messages_intro'),
        isNull,
      );
    },
  );
}
