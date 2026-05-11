import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MatchAManApp());
}
