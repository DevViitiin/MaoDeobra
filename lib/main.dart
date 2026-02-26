import 'package:dartobra_new/screens/screens_init/splash_screen/splash_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:dartobra_new/screens/screens_init/login_screen/login_screen.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dartobra_new/screens/actions_administrave/warning_screen/warning_screen.dart';
import 'package:dartobra_new/screens/screens_init/register_screens/onboarding_first/onboarding_first.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // ✅ ADICIONAR
import 'package:hive_flutter/hive_flutter.dart'; // ✅ ADICIONAR
import 'firebase_options.dart';

// ✅ IMPORTAR O FEED CONTROLLER
import 'package:dartobra_new/controllers/feed_controller.dart';
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Mensagem em background: ${message.notification?.title}');
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ INICIALIZAR HIVE (para cache persistente)
  await Hive.initFlutter();
  
  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    // ✅ ENVOLVER COM MULTIPROVIDER
    return MultiProvider(
      providers: [
        // ✅ FEED CONTROLLER COM PROVIDER
        ChangeNotifierProvider(
          create: (_) => FeedController(),
          // lazy: false significa que será criado imediatamente
          // Mude para true se quiser criar apenas quando for usado pela primeira vez
          lazy: true,
        ),
        
        // ✅ ADICIONE OUTROS PROVIDERS AQUI CONFORME NECESSÁRIO
        // Exemplo:
        // ChangeNotifierProvider(create: (_) => UserController()),
        // ChangeNotifierProvider(create: (_) => ChatController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mão de Obra',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          // ✅ OPCIONAL: Configurações adicionais de tema
          useMaterial3: true, // Usar Material 3 (opcional)
        ),

        routes: {
          '/': (context) => SplashPage(),
          '/LoginScreen': (context) => LoginScreen(),
          '/onboarding_first': (context) => OnboardingFirst(),
        },

        onGenerateRoute: (settings) {
          if (settings.name == '/warning_screen') {
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (context) => WarningScreen(
                  occurrenceDate: args['occurrenceDate'] ?? '',
                  type: args['type'] ?? '',
                  local_id: args['local_id'] ?? '',
                  userData: args['userData'] ?? {},
                  reason: args['reason'] ?? '',
                  description: args['description'] ?? '',
                ),
              );
            }
            return MaterialPageRoute(builder: (context) => LoginScreen());
          }

          return null;
        },
      ),
    );
  }
}