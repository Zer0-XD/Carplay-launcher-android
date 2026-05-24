import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/ui_scale.dart';
import 'data/repositories_impl/app_repository_impl.dart';
import 'data/repositories_impl/settings_repository_impl.dart';
import 'data/services/media_service.dart';
import 'data/services/native_app_service.dart';
import 'data/services/power_event_service.dart';
import 'presentation/pages/permissions/permission_gate.dart';
import 'presentation/providers/app_list_provider.dart';
import 'presentation/providers/edit_mode_provider.dart';
import 'presentation/providers/media_provider.dart';
import 'presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final settingsRepo = SettingsRepositoryImpl();
  final appRepo = AppRepositoryImpl(NativeAppService.instance);

  final settingsProvider = SettingsProvider(settingsRepo);
  await settingsProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => AppListProvider(appRepo)),
        ChangeNotifierProvider(create: (_) => EditModeProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider(MediaService(), PowerEventService())),
      ],
      child: const _App(),
    ),
  );
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final isDark = sp.isDarkMode;
    final accent = AppTheme.accentColorValue(sp.settings.accentColor);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CarPlay Launcher',
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(accent: accent),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        // Resolve scale once per settings change — never per frame.
        final view = View.of(context);
        final scale = resolveUiScale(sp.settings.uiScale, view);

        // Override MediaQuery so that:
        //  • textScaler scales all Text widgets proportionally
        //  • The logical screen size stays untouched (no GPU transform)
        // This is zero-cost at runtime — it's just data propagation.
        final mq = MediaQuery.of(context);
        return _UiScaleScope(
          scale: scale,
          child: MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        );
      },
      home: const PermissionGate(),
    );
  }
}

/// InheritedWidget that propagates the resolved UI scale factor down the tree
/// so layout widgets (sidebar, cards) can read it without a Provider lookup.
class _UiScaleScope extends InheritedWidget {
  const _UiScaleScope({required this.scale, required super.child});

  final double scale;

  static double of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_UiScaleScope>();
    return scope?.scale ?? 1.0;
  }

  @override
  bool updateShouldNotify(_UiScaleScope old) => old.scale != scale;
}

/// Convenience extension so any widget can call `context.uiScale`.
extension UiScaleContext on BuildContext {
  double get uiScale => _UiScaleScope.of(this);
}
