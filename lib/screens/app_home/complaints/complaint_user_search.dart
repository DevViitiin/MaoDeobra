import 'package:dartobra_new/screens/app_home/complaints/complaint_user.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SearchUserToComplaint extends StatefulWidget {
  final String UserEmailContact;
  final String Company;
  
  const SearchUserToComplaint({Key? key, required this.UserEmailContact, required this.Company})
    : super(key: key);

  @override
  State<SearchUserToComplaint> createState() => _SearchUserToComplaintState();
}

class _SearchUserToComplaintState extends State<SearchUserToComplaint> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _foundUserId;
  String _searchType = 'email'; // 'email' ou 'company'
  bool _isSelfReport = false; // Nova flag para auto-denúncia

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _checkIfSelfReport(Map<String, dynamic> userData) {
    // Verificar se o email de contato é o mesmo
    final foundEmailContact = (userData['email_contact'] ?? '').toString().toLowerCase();
    final foundEmail = (userData['email'] ?? '').toString().toLowerCase();
    final currentEmail = widget.UserEmailContact.toLowerCase();

    if (foundEmailContact == currentEmail || foundEmail == currentEmail) {
      return true;
    }

    // Verificar se a empresa é a mesma
    final contractorCompany = (userData['data_contractor']?['company'] ?? '').toString().toLowerCase();
    final workerCompany = (userData['data_worker']?['company'] ?? '').toString().toLowerCase();
    final currentCompany = widget.Company.toLowerCase();

    if ((contractorCompany.isNotEmpty && contractorCompany == currentCompany) ||
        (workerCompany.isNotEmpty && workerCompany == currentCompany)) {
      return true;
    }

    return false;
  }

  Future<void> _searchUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _foundUserId = null;
      _isSelfReport = false;
    });

    try {
      final DatabaseReference usersRef = FirebaseDatabase.instance.ref('Users');
      final snapshot = await usersRef.get();

      if (snapshot.exists) {
        final usersData = Map<String, dynamic>.from(snapshot.value as Map);

        final searchValue = _searchController.text.trim().toLowerCase();

        // Buscar usuário
        for (var entry in usersData.entries) {
          final userId = entry.key;
          final userData = Map<String, dynamic>.from(entry.value as Map);

          bool found = false;

          if (_searchType == 'email') {
            final emailContact = (userData['email_contact'] ?? '')
                .toString()
                .toLowerCase();
            final email = (userData['email'] ?? '').toString().toLowerCase();
            found = emailContact == searchValue || email == searchValue;
          } else {
            // Buscar por empresa (contractor ou worker)
            final contractorCompany =
                (userData['data_contractor']?['company'] ?? '')
                    .toString()
                    .toLowerCase();
            final workerCompany = (userData['data_worker']?['company'] ?? '')
                .toString()
                .toLowerCase();
            found =
                contractorCompany.contains(searchValue) ||
                workerCompany.contains(searchValue);
          }

          if (found) {
            // Verificar se é auto-denúncia
            final isSelf = _checkIfSelfReport(userData);
            
            setState(() {
              _foundUser = userData;
              _foundUserId = userId;
              _isSelfReport = isSelf;
            });
            break;
          }
        }

        if (_foundUser == null) {
          _showError('Usuário não encontrado');
        }
      } else {
        _showError('Nenhum usuário encontrado no banco de dados');
      }
    } catch (e) {
      _showError('Erro ao buscar usuário: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmAndProceed() {
    if (_foundUser == null || _foundUserId == null || _isSelfReport) return;

    // Navegar para a tela de denúncia passando os dados do usuário
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintUser(
          reportedId: _foundUserId!,
          reportedName: _foundUser!['Name'] ?? 'Não definido',
          reportedEmail: _foundUser!['email_contact'] ?? 'Não definido',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Buscar Usuário',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Denunciar Usuário',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Busque o usuário que deseja denunciar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tipo de busca
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buscar por:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSearchTypeButton(
                            'Email',
                            'email',
                            Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSearchTypeButton(
                            'Empresa',
                            'company',
                            Icons.business_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo de busca
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: _searchType == 'email'
                        ? 'Digite o email do usuário'
                        : 'Digite o nome da empresa',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(
                      _searchType == 'email' ? Icons.email : Icons.business,
                      color: Colors.red.shade400,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite um valor para buscar';
                    }
                    if (_searchType == 'email' && !value.contains('@')) {
                      return 'Digite um email válido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Botão de buscar
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade800],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade300,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Buscar Usuário',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Resultado da busca - Mensagem de auto-denúncia
              if (_foundUser != null && _isSelfReport) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.block_rounded,
                          size: 48,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Não Permitido',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Você não pode denunciar a si mesmo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'O usuário encontrado possui o mesmo email ou empresa que você',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _foundUser = null;
                              _foundUserId = null;
                              _isSelfReport = false;
                              _searchController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Fazer Nova Busca',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Resultado da busca - Usuário válido
              if (_foundUser != null && !_isSelfReport) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Usuário Encontrado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Avatar e Nome
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundImage: NetworkImage(
                              _foundUser!['avatar'] ??
                                  'https://res.cloudinary.com/dsmgwupky/image/upload/v1731970845/image_3_uiwlog.png',
                            ),
                            backgroundColor: Colors.grey.shade200,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundUser!['Name'] ?? 'Não definido',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _foundUser!['email_contact'] ??
                                      'Não definido',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Informações adicionais
                      _buildInfoRow(
                        Icons.location_city,
                        'Cidade',
                        '${_foundUser!['city'] ?? 'Não definido'}, ${_foundUser!['state'] ?? ''}',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.work_outline,
                        'Empresa',
                        _foundUser!['activeMode'] == 'contractor'
                            ? (_foundUser!['data_contractor']?['company'] ??
                                  'Não definido')
                            : (_foundUser!['data_worker']?['company'] ??
                                  'Não definido'),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'Profissão',
                        _foundUser!['activeMode'] == 'contractor'
                            ? (_foundUser!['data_contractor']?['profession'] ??
                                  'Não definido')
                            : (_foundUser!['data_worker']?['profession'] ??
                                  'Não definido'),
                      ),

                      const SizedBox(height: 24),

                      // Pergunta de confirmação
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Este é o usuário que deseja denunciar?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botões de confirmação
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _foundUser = null;
                                  _foundUserId = null;
                                  _isSelfReport = false;
                                  _searchController.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Não',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirmAndProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Sim, continuar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTypeButton(String label, String type, IconData icon) {
    final isSelected = _searchType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _searchType = type;
          _searchController.clear();
          _foundUser = null;
          _foundUserId = null;
          _isSelfReport = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.red.shade600 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}