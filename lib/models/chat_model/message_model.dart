class Message {
  final String id;
  final String sender; // 'contractor' ou 'employee'
  final String text;
  final int timestamp;
  final bool readByContractor;
  final bool readByEmployee;

  Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.readByContractor = false,
    this.readByEmployee = false,
  });

  // Parse do Firebase
  factory Message.fromMap(String id, Map<dynamic, dynamic> map) {
    return Message(
      id: id,
      sender: map['sender'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] as int? ?? 0,
      readByContractor: map['read_by_contractor'] as bool? ?? false,
      readByEmployee: map['read_by_employee'] as bool? ?? false,
    );
  }

  // Para enviar ao Firebase
  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'timestamp': timestamp,
      'read_by_contractor': readByContractor,
      'read_by_employee': readByEmployee,
    };
  }

  // Helper: se foi lida pelo usuário atual
  bool isReadBy(String role) {
    return role == 'contractor' ? readByContractor : readByEmployee;
  }

  // CopyWith para atualizações
  Message copyWith({
    String? id,
    String? sender,
    String? text,
    int? timestamp,
    bool? readByContractor,
    bool? readByEmployee,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      readByContractor: readByContractor ?? this.readByContractor,
      readByEmployee: readByEmployee ?? this.readByEmployee,
    );
  }
}
