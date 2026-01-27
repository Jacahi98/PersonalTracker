import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importamos tu archivo principal
import 'package:app_track_financiero/main.dart';

void main() {
  testWidgets('La app arranca correctamente', (WidgetTester tester) async {
    // 1. Cargamos tu app (Fíjate que ahora usamos MiAppFinanciera)
    await tester.pumpWidget(const MiAppFinanciera());

    // 2. Comprobamos que el título "Mis Finanzas" aparece en pantalla
    expect(find.text('Mis Finanzas'), findsOneWidget);

    // 3. Comprobamos que NO aparece un texto de contador (porque ya no existe)
    expect(find.text('0'), findsNothing);
  });
}