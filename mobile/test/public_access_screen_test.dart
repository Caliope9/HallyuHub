import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/screens/beta_signup_screen.dart';
import 'package:hallyuhub/src/services/beta_signup_service.dart';

void main() {
  testWidgets('public access screen keeps the signup flow visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BetaSignupScreen(betaSignupService: LocalBetaSignupService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acceso anticipado'), findsOneWidget);
    expect(find.text('Sumate al acceso anticipado'), findsWidgets);
    expect(find.text('Ya me anoté'), findsOneWidget);
    expect(find.text('Consultar estado'), findsOneWidget);
    expect(find.textContaining('16 años o más'), findsOneWidget);
    expect(find.textContaining('Instagram o WhatsApp'), findsOneWidget);
    expect(find.text('Entrar a HallyuHub'), findsNothing);
  });
}
