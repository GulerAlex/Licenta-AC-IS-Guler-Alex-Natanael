import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unihub/main.dart';
import 'package:unihub/supabase/supabase_config.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  testWidgets('Login screen is shown first', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Bine ai venit'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Parola'), findsOneWidget);
    expect(find.text('Autentificare'), findsOneWidget);
  });
}
