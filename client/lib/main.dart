import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/vault/screens/vault_home_screen.dart';
import 'features/vault/services/vault_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase (Credenciales de entorno o demo local)
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://demo-passwords-vault.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_anon_key_for_offline_dev',
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

  void _onLock() {
    _syncService?.dispose();
    setState(() {
      _activeMasterEncryptionKey = null;
      _syncService = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bóveda bloqueada. Claves criptográficas eliminadas de la memoria RAM.'),
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeVault - Gestor Cero-Conocimiento',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111418),
        cardTheme: const CardTheme(
          color: Color(0xFF1A1F26),
        ),
      ),
      home: _activeMasterEncryptionKey != null && _syncService != null
          ? VaultHomeScreen(
              key: UniqueKey(),
              syncService: _syncService!,
              onLock: _onLock,
            )
          : AuthScreen(
              onUnlockSuccess: _onUnlock,
            ),
    );
  }
}
