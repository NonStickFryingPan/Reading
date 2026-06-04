import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'providers/feed_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  try {
    await storage.init();
  } catch (error, stackTrace) {
    debugPrint('Unexpected storage startup failure: $error\n$stackTrace');
  }

  runApp(ReadingApp(storage: storage));
}

class ReadingApp extends StatelessWidget {
  final StorageService storage;

  const ReadingApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedProvider(storage)..init(),
      child: Selector<FeedProvider, bool>(
        selector: (_, provider) => provider.darkMode,
        builder: (context, darkMode, _) {
          return MaterialApp(
            title: 'Reading',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
