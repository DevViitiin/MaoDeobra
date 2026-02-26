// lib/services/professional_status_service.dart
// 🔄 SERVIÇO DE STATUS DE PERFIS PROFISSIONAIS
// Gerencia ativação e pausa de perfis profissionais (similar às vagas)

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfessionalStatusService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // ==========================================
  // 🔹 ATIVAR PERFIL PROFISSIONAL
  // ==========================================
  /// Ativa o perfil profissional no banco de dados
  /// Define status como 'active' e atualiza data_worker/activated
  static Future<bool> activateProfessionalProfile() async {
    if (_currentUserId == null) {
      print('❌ Usuário não autenticado');
      return false;
    }

    try {
      print('🔄 Ativando perfil profissional...');

      // Buscar o ID do perfil profissional no nó 'professionals'
      final profSnapshot = await _db
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(_currentUserId)
          .once();

      if (profSnapshot.snapshot.value == null) {
        print('⚠️ Perfil profissional não encontrado em professionals/');
        return false;
      }

      final profData = profSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final professionalId = profData.keys.first;

      // Atualiza status para 'active' no nó professionals
      await _db.child('professionals/$professionalId/status').set('active');

      // Atualiza data de modificação
      await _db.child('professionals/$professionalId/updated_at')
          .set(DateTime.now().toIso8601String());

      // Atualiza isActive no nó Users
      await _db.child('Users/$_currentUserId/isActive').set(true);

      // Atualiza activated em data_worker
      await _db.child('Users/$_currentUserId/data_worker/activated').set(true);

      print('✅ Perfil profissional ativado com sucesso!');
      return true;

    } catch (e) {
      print('❌ Erro ao ativar perfil profissional: $e');
      return false;
    }
  }

  // ==========================================
  // 🔹 PAUSAR PERFIL PROFISSIONAL
  // ==========================================
  /// Pausa o perfil profissional no banco de dados
  /// Define status como 'paused' (não aparecerá em buscas)
  static Future<bool> pauseProfessionalProfile() async {
    if (_currentUserId == null) {
      print('❌ Usuário não autenticado');
      return false;
    }

    try {
      print('⏸️ Pausando perfil profissional...');

      // Buscar o ID do perfil profissional
      final profSnapshot = await _db
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(_currentUserId)
          .once();

      if (profSnapshot.snapshot.value == null) {
        print('⚠️ Perfil profissional não encontrado');
        return false;
      }

      final profData = profSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final professionalId = profData.keys.first;

      // Atualiza status para 'paused' no nó professionals
      await _db.child('professionals/$professionalId/status').set('paused');

      // Atualiza data de modificação
      await _db.child('professionals/$professionalId/updated_at')
          .set(DateTime.now().toIso8601String());

      // Atualiza isActive no nó Users
      await _db.child('Users/$_currentUserId/isActive').set(false);

      // Atualiza activated em data_worker
      await _db.child('Users/$_currentUserId/data_worker/activated').set(false);

      print('✅ Perfil profissional pausado com sucesso!');
      return true;

    } catch (e) {
      print('❌ Erro ao pausar perfil profissional: $e');
      return false;
    }
  }

  // ==========================================
  // 🔹 VERIFICAR STATUS DO PERFIL
  // ==========================================
  /// Verifica se o perfil profissional está ativo
  static Future<ProfessionalStatus> getProfessionalStatus() async {
    if (_currentUserId == null) {
      return ProfessionalStatus(
        isActive: false,
        professionalId: null,
        message: 'Usuário não autenticado',
      );
    }

    try {
      // Buscar o perfil profissional
      final profSnapshot = await _db
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(_currentUserId)
          .once();

      if (profSnapshot.snapshot.value == null) {
        return ProfessionalStatus(
          isActive: false,
          professionalId: null,
          message: 'Perfil profissional não encontrado',
        );
      }

      final profData = profSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final professionalId = profData.keys.first;
      final data = Map<String, dynamic>.from(profData[professionalId]);

      final status = data['status']?.toString().toLowerCase() ?? '';
      final isActive = (status == 'active' || status == 'ativo');

      return ProfessionalStatus(
        isActive: isActive,
        professionalId: professionalId,
        status: status,
        message: isActive 
            ? 'Perfil profissional ativo' 
            : 'Perfil profissional pausado',
      );

    } catch (e) {
      print('❌ Erro ao verificar status: $e');
      return ProfessionalStatus(
        isActive: false,
        professionalId: null,
        message: 'Erro ao verificar status',
      );
    }
  }

  // ==========================================
  // 🔹 ALTERNAR STATUS (TOGGLE)
  // ==========================================
  /// Alterna entre ativo e pausado
  static Future<bool> toggleProfessionalStatus() async {
    final currentStatus = await getProfessionalStatus();
    
    if (currentStatus.isActive) {
      return await pauseProfessionalProfile();
    } else {
      return await activateProfessionalProfile();
    }
  }
}

// ==========================================
// 🔹 CLASSE DE STATUS
// ==========================================
class ProfessionalStatus {
  final bool isActive;
  final String? professionalId;
  final String? status;
  final String message;

  ProfessionalStatus({
    required this.isActive,
    required this.professionalId,
    this.status,
    required this.message,
  });

  @override
  String toString() {
    return 'ProfessionalStatus(isActive: $isActive, professionalId: $professionalId, status: $status)';
  }
}