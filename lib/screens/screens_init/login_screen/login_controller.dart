import 'package:dartobra_new/services/services_notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/actions_administrave/ban_screen/ban_screen.dart';
import 'package:dartobra_new/screens/actions_administrave/suspension_screen/suspension_screen.dart';
import 'package:intl/intl.dart';
import 'package:dartobra_new/screens/actions_administrave/warning_screen/warning_screen.dart';
import 'package:dartobra_new/screens/app_home/home_screen/home_screen.dart';

class LoginController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String typeController = 'contractor';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final db = FirebaseDatabase.instance.ref();

  Map<String, dynamic>? userData;

  Future<void> GetDataUser(String? localId) async {
    if (localId == null) {
      print('⚠️ localId é null');
      return;
    }

    if (typeController == 'contractor') {
      userData = await GetUser(localId);
    } else {
      userData = await GetUser(localId);
    }
  }

  // ✅ Função helper para converter Map do Firebase recursivamente
  Map<String, dynamic> _convertMap(dynamic map) {
    if (map == null) return {};
    if (map is Map<String, dynamic>) return map;
    if (map is Map) {
      return Map<String, dynamic>.from(
        map.map((key, value) {
          if (value is Map) {
            return MapEntry(key.toString(), _convertMap(value));
          } else if (value is List) {
            return MapEntry(
              key.toString(),
              value.map((e) => e is Map ? _convertMap(e) : e).toList(),
            );
          }
          return MapEntry(key.toString(), value);
        }),
      );
    }
    return {};
  }

  Future<Map<String, dynamic>?> GetUser(String uid) async {
    try {
      final userRef = db.child('Users').child(uid);
      final data = await userRef.get();

      if (data.exists && data.value != null) {
        final value = data.value;

        if (value is Map) {
          // ✅ Conversão profunda recursiva
          final userData = _convertMap(value);
          print('✅ Usuário encontrado: $userData');
          return userData;
        } else {
          print('❌ Valor não é um Map, é: ${value.runtimeType}');
          return null;
        }
      }

      print('❌ Usuário não encontrado');
      return null;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar usuário: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Iniciando login para: $email');

      // Tentar fazer login
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Login bem-sucedido! UID: ${credential.user?.uid}');
      return {'success': true, 'user': credential.user};
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException - Código: ${e.code}');

      // Todos os erros de credenciais (email ou senha incorretos)
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return {
          'success': false,
          'user': null,
          'errorType': 'credentials',
          'message':
              'Email ou senha incorretos. Verifique suas credenciais e tente novamente.',
        };
      } else if (e.code == 'invalid-email') {
        return {
          'success': false,
          'user': null,
          'errorType': 'credentials',
          'message': 'Formato de email inválido.',
        };
      } else if (e.code == 'user-disabled') {
        return {
          'success': false,
          'user': null,
          'errorType': 'other',
          'message':
              'Esta conta foi desabilitada. Entre em contato com o suporte.',
        };
      } else if (e.code == 'too-many-requests') {
        return {
          'success': false,
          'user': null,
          'errorType': 'other',
          'message':
              'Muitas tentativas de login. Por segurança, aguarde alguns minutos antes de tentar novamente.',
        };
      } else if (e.code == 'network-request-failed') {
        return {
          'success': false,
          'user': null,
          'errorType': 'network',
          'message':
              'Erro de conexão. Verifique sua internet e tente novamente.',
        };
      }

      // Erro genérico
      return {
        'success': false,
        'user': null,
        'errorType': 'other',
        'message': 'Erro ao fazer login. Tente novamente em instantes.',
      };
    } catch (e) {
      print('❌ Erro inesperado: $e');
      return {
        'success': false,
        'user': null,
        'errorType': 'other',
        'message': 'Erro inesperado. Tente novamente.',
      };
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> NextScreenUser(
    BuildContext context,
    Map<String, dynamic> userData,
    String localId,
  ) async {
    final ban = userData['ban'];
    final suspension = userData['suspension'];
    final warnings = userData['warning']; 

    if (ban != null &&
        ban is Map &&
        ban.values.any(
          (value) => value != null && value.toString().isNotEmpty,
        )) {
      print('Navegar para a tela de banimento');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BanScreen(
            occurrenceDate: ban['data'],
            reason: ban['motive'],
            description: ban['description'],
          ),
        ),
      );
    } else if (suspension != null &&
        suspension is Map &&
        suspension.values.any(
          (value) => value != null && value.toString().isNotEmpty,
        )) {
      print('Navegar para a tela de suspensão');
      // Converter strings para DateTime
      final dataInicio = suspension['init'];
      final dataFim = suspension['end'];
      DateTime fim = DateFormat('dd/MM/yyyy').parse(dataFim);
      DateTime inicio = DateFormat('dd/MM/yyyy').parse(dataInicio);

      // Calcular diferença em dias
      int diferencaDias = fim.difference(inicio).inDays;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuspensionScreen(
            reason: suspension['motive'],
            description: suspension['description'],
            startDate: suspension['init'],
            endDate: suspension['end'],
            occurrenceDate: suspension['data'],
            daysRemaining: diferencaDias,
          ),
        ),
      );
    } else if (warnings != null &&
        warnings is Map &&
        warnings.values.any(
          (value) => value != null && value.toString().isNotEmpty,
        )) {
      print('Navegar para a tela de advertências');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WarningScreen(
            reason: warnings['motive'],
            description: warnings['description'],
            local_id: localId,
            occurrenceDate: warnings['data'],
            type: warnings['type']?.toString() ?? 'contractor',
            userData: userData,
          ),
        ),
      );
    } else {
      // ✅ Extrair e converter dados corretamente do Map
      final dataWorker = _convertMap(userData['data_worker']);
      final dataContractor = _convertMap(userData['data_contractor']);

      // ✅ Converter age de forma segura
      int age = 0;
      if (userData['age'] != null) {
        if (userData['age'] is int) {
          age = userData['age'];
        } else if (userData['age'] is String) {
          age = int.tryParse(userData['age']) ?? 0;
        } else if (userData['age'] is double) {
          age = (userData['age'] as double).toInt();
        }
      }
      final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await NotificationService().initialize(user.uid);
        }
      print('🏠 Navegando para HomeScreen');
      print('dataWorker convertido: $dataWorker');
      print('dataContractor convertido: $dataContractor');
      print('Age convertido: $age');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            local_id: localId,
            userName: userData['Name']?.toString() ?? '',
            userEmail: userData['email']?.toString() ?? '',
            userPhone: userData['telefone']?.toString() ?? '',
            contact_email: userData['email_contact']?.toString() ?? '',
            legalType: userData['legalType']?.toString() ?? 'PF',
            userCity: userData['city']?.toString() ?? '',
            userState: userData['state']?.toString() ?? '',
            age: age,
            userAvatar: userData['avatar']?.toString() ?? '',
            finished_basic: userData['finished_basic'] == true,
            finished_professional: userData['finished_professional'] == true,
            finished_contact: userData['finished_contact'] == true,
            isActive: userData['isActive'] == true,
            activeMode: userData['activeMode']?.toString() ?? 'worker',
            dataWorker: dataWorker,
            dataContractor: dataContractor,
          ),
        ),
      );
    };
  }

  void nextScreen(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/onboarding_first');
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}
