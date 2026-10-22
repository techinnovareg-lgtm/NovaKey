import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/security/auto_lock_wrapper.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/vault/screens/vault_home_screen.dart';
import 'features/vault/services/vault_sync_service.dart';
import 'features/subscription/screens/superadmin_dashboard_screen.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase con el proyecto oficial de NovaKey
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ysnjstolpjszgjsmtjkc.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzbmpzdG9scGpzemdqc210amtjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1MjgxNjcsImV4cCI6MjEwODEwNDE2N30.0LDVtePPUoT6ly0JE3riMu8Z05poeuOQuQBRlfTwx3E',
  );

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase no configurado o modo offline: $e');
  }

  runApp(const SafeVaultApp());
}

class SafeVaultApp extends StatefulWidget {
  const SafeVaultApp({super.key});

  @override
  State<SafeVaultApp> createState() => _SafeVaultAppState();
}

class _SafeVaultAppState extends State<SafeVaultApp> {
  SecretKey? _activeMasterEncryptionKey;
  VaultSyncService? _syncService;
  Duration _autoLockTimeout = const Duration(minutes: 2); // 2 minutos por defecto

  void _onUnlock(SecretKey key, String email) {
    final client = Supabase.instance.client;
    setState(() {
      _activeMasterEncryptionKey = key;
      _syncService = VaultSyncService(
        supabase: client,
        masterEncryptionKey: key,
        userEmail: email,
      );
    });
  }

  void _onLock({bool dueToInactivity = false}) {
    _syncService?.dispose();
    setState(() {
      _activeMasterEncryptionKey = null;
      _syncService = null;
    });

    final message = dueToInactivity
        ? '🔒 Sesión cerrada automáticamente por inactividad para proteger tus datos.'
        : 'Bóveda bloqueada. Claves criptográficas eliminadas de la memoria RAM.';

    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              dueToInactivity ? Icons.timer_off_rounded : Icons.lock_rounded,
              color: dueToInactivity ? Colors.amberAccent : Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: dueToInactivity
                ? Colors.amberAccent.withOpacity(0.5)
                : Colors.blueAccent.withOpacity(0.4),
          ),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'NovaKey - Bóveda Cero-Conocimiento',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        cardTheme: const CardTheme(
          color: Color(0xFF111827),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1E40AF),
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: _activeMasterEncryptionKey != null && _syncService != null
          ? AutoLockWrapper(
              timeout: _autoLockTimeout,
              isEnabled: true,
              onTimeout: () => _onLock(dueToInactivity: true),
              child: (_syncService!.userEmail.toLowerCase().trim() == 'tech.innova.reg@gmail.com' ||
                      _syncService!.userEmail.toLowerCase().trim() == 'carlos.amambal@tech-innova.online')
                  ? SuperAdminDashboardScreen(
                      key: UniqueKey(),
                      syncService: _syncService!,
                      onLock: () => _onLock(dueToInactivity: false),
                      currentTimeout: _autoLockTimeout,
                      onTimeoutChanged: (newTimeout) {
                        setState(() => _autoLockTimeout = newTimeout);
                      },
                    )
                  : VaultHomeScreen(
                      key: UniqueKey(),
                      syncService: _syncService!,
                      onLock: () => _onLock(dueToInactivity: false),
                      currentTimeout: _autoLockTimeout,
                      onTimeoutChanged: (newTimeout) {
                        setState(() => _autoLockTimeout = newTimeout);
                      },
                    ),
            )
          : AuthScreen(
              onUnlockSuccess: _onUnlock,
            ),
    );
  }
}
