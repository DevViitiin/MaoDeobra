import 'package:firebase_database/firebase_database.dart';

class WarningController {
  String local_id; // ✅ String
  String type;     
  
  WarningController({required this.local_id, required this.type});

  Future<bool> patchUserData(Map<String, dynamic> updates) async {
    DatabaseReference ref;
    
    if (type == 'contractor') {
      ref = FirebaseDatabase.instance.ref().child('Users/$local_id');
    } else if (type == 'employee') {
      ref = FirebaseDatabase.instance.ref().child('Funcionarios/$local_id');
    } else {
      print('Tipo de usuário inválido: $type');
      return false;
    }

    try {
      await ref.update(updates);
      print('✅ Advertência removida com sucesso');
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar: $e');
      return false;
    }
  }
}