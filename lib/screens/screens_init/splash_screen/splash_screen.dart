import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/app_home/home_screen/home_screen.dart';
// ignore: unused_import
import 'package:dartobra_new/screens/screens_init/login_screen/login_screen.dart';
import 'package:dartobra_new/screens/actions_administrave/ban_screen/ban_screen.dart';
import 'package:dartobra_new/screens/actions_administrave/suspension_screen/suspension_screen.dart';
import 'package:dartobra_new/screens/actions_administrave/warning_screen/warning_screen.dart';
import 'package:intl/intl.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _logoAnimation;
  late Animation<double> _pulseAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    
    // Animação de fade in + scale da logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    
    // Animação de pulso do loading
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Animação de rotação
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _logoController.forward();
    _initApp();
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

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final userRef = db.child('Users').child(uid);
      final data = await userRef.get();

      if (data.exists && data.value != null) {
        final value = data.value;

        if (value is Map) {
          final userData = _convertMap(value);
          print('✅ Usuário encontrado: $userData');
          return userData;
        } else {
          print('❌ Valor não é um Map, é: ${value.runtimeType}');
          return null;
        }
      }

      print('❌ Usuário não encontrado no banco de dados');
      return null;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar usuário: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  void _navigateToScreen(Map<String, dynamic> userData, String localId) {
    final ban = userData['ban'];
    final suspension = userData['suspension'];
    final warnings = userData['warning'];

    if (ban != null &&
        ban is Map &&
        ban.values.any(
          (value) => value != null && value.toString().isNotEmpty,
        )) {
      print('🚫 Usuário banido - Navegando para BanScreen');
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
      print('⏸️ Usuário suspenso - Navegando para SuspensionScreen');
      final dataInicio = suspension['init'];
      final dataFim = suspension['end'];
      DateTime fim = DateFormat('dd/MM/yyyy').parse(dataFim);
      DateTime inicio = DateFormat('dd/MM/yyyy').parse(dataInicio);
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
      print('⚠️ Usuário com advertência - Navegando para WarningScreen');
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

      print('🏠 Navegando para HomeScreen com dados atualizados');
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
    }
  }

  Future<void> _initApp() async {
    try {
      // Aguarda as animações iniciais
      await Future.delayed(const Duration(milliseconds: 1500));

      // Verifica se há usuário logado
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        print('✅ Usuário já está logado: ${currentUser.uid}');
        
        // Busca dados atualizados do usuário no Firebase
        final userData = await _getUserData(currentUser.uid);

        if (userData != null && mounted) {
          // Navega para a tela apropriada com dados atualizados
          _navigateToScreen(userData, currentUser.uid);
        } else {
          // Se não encontrou dados, faz logout e vai para login
          print('⚠️ Dados do usuário não encontrados, fazendo logout...');
          await _auth.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/LoginScreen');
          }
        }
      } else {
        // Não há usuário logado, vai para tela de login
        print('❌ Nenhum usuário logado');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/LoginScreen');
        }
      }
    } catch (e) {
      print('❌ Erro ao inicializar app: $e');
      // Em caso de erro, vai para login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/LoginScreen');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Blue 900
              Color(0xFF3B82F6), // Blue 500
              Color(0xFF60A5FA), // Blue 400
            ],
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos de fundo
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            
            // Conteúdo principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo com animação
                  ScaleTransition(
                    scale: _logoAnimation,
                    child: FadeTransition(
                      opacity: _logoAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo_no_bg.png',
                          width: 150,
                          height: 200,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Nome do app
                  FadeTransition(
                    opacity: _logoAnimation,
                    child: Column(
                      children: [
                        Text(
                          'MãoDeObra',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conectando profissionais',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Loading indicator animado
                  AnimatedBuilder(
                    animation: _rotateController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotateController.value * 2 * math.pi,
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Versão do app no rodapé
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _logoAnimation,
                child: Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}