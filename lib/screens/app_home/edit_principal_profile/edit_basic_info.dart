import 'dart:io';
import 'package:dartobra_new/services/services_storage/service_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dartobra_new/screens/app_home/edit_principal_profile/components.dart';

class EditBasicInfoScreen extends StatefulWidget {
  final String local_id;
  final String userName;
  final String userEmail;
  final bool finished_basic;
  final String userPhone;
  final String userCity;
  final String userState;
  final int userAge;
  final String userAvatar;
  final String legalType;
  final String company;
  final String activeMode;
  final String profession;
  final String summary;
  final List<String> skills;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;

  EditBasicInfoScreen({
    required this.local_id,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userCity,
    required this.userState,
    required this.finished_basic,
    required this.userAge,
    required this.userAvatar,
    required this.legalType,
    required this.company,
    required this.dataWorker,
    required this.dataContractor,
    required this.activeMode,
    required this.profession,
    required this.summary,
    required this.skills,
  });

  @override
  _EditBasicInfoScreenState createState() => _EditBasicInfoScreenState();
}

class _EditBasicInfoScreenState extends State<EditBasicInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorageService _storageService = FirebaseStorageService(); // ✅ NOVO
  
  // FocusNode para controle de foco
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _dummyFocus = FocusNode();

  String? selectedState;
  String? selectedCity;
  File? _profileImage;
  String? _currentAvatarUrl;
  String? _oldAvatarUrl;
  bool _isSaving = false;
  double _uploadProgress = 0.0; // ✅ NOVO - Progress bar

  @override
  void initState() {
    super.initState();
    
    _nameController.text = widget.userName;
    _ageController.text = widget.userAge > 0 ? widget.userAge.toString() : '';
    selectedState = widget.userState.isNotEmpty ? widget.userState : null;
    selectedCity = widget.userCity.isNotEmpty ? widget.userCity : null;
    _currentAvatarUrl = widget.userAvatar.isNotEmpty ? widget.userAvatar : null;
    _oldAvatarUrl = _currentAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _nameFocus.dispose();
    _dummyFocus.dispose();
    super.dispose();
  }

  Future<bool> _checkAndRequestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    } else {
      if (Platform.isIOS) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        final status = await Permission.photos.request();
        if (status.isGranted) return true;
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
    }
  }

  void _removeFocusCompletely() {
    _nameFocus.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Future.delayed(Duration(milliseconds: 10), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_dummyFocus);
        Future.delayed(Duration(milliseconds: 10), () {
          if (mounted) {
            _dummyFocus.unfocus();
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
      }
    });
  }

  Future<void> _showImageSourceModal() async {
    _removeFocusCompletely();
    
    await Future.delayed(Duration(milliseconds: 100));
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue, size: 28),
              title: Text('Tirar Foto', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.camera);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.blue, size: 28),
              title: Text('Escolher da Galeria', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.gallery);
              },
            ),
            if (_profileImage != null || _currentAvatarUrl != null) ...[
              Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red, size: 28),
                title: Text('Remover Foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImage = null;
                    _currentAvatarUrl = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    ).then((_) {
      _removeFocusCompletely();
    });
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final hasPermission = await _checkAndRequestPermissions(source);
    if (!hasPermission) {
      _showSnackBar('Permissão negada', isError: true);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source, 
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _currentAvatarUrl = null;
        });
      }
    } catch (e) {
      print('Erro ao selecionar imagem: $e');
      _showSnackBar('Erro ao selecionar imagem', isError: true);
    }
  }

  Future<void> _saveChanges() async {
    // Validações
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Digite seu nome', isError: true);
      return;
    }

    if (_ageController.text.trim().isEmpty) {
      _showSnackBar('Digite sua idade', isError: true);
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 18 || age > 120) {
      _showSnackBar('Digite uma idade válida (18-120)', isError: true);
      return;
    }

    if (selectedState == null || selectedCity == null) {
      _showSnackBar('Selecione estado e cidade', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      String? avatarUrl = _currentAvatarUrl;
      bool shouldDeleteOldImage = false;
      String? oldImageToDelete;

      // ✅ NOVO: Upload usando Firebase Storage
      if (_profileImage != null) {
        _showSnackBar('Fazendo upload da imagem...', isError: false);
        
        avatarUrl = await _storageService.uploadImage(
          file: _profileImage!,
          folder: 'profiles',
          userId: widget.local_id,
          quality: 70,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
        
        if (avatarUrl == null) {
          final shouldContinue = await _showConfirmDialog(
            'Erro no Upload',
            'Não foi possível fazer upload da imagem. Deseja salvar sem atualizar a foto?',
          );
          
          if (!shouldContinue) {
            setState(() {
              _isSaving = false;
            });
            return;
          }
          
          avatarUrl = _currentAvatarUrl;
        } else {
          // Marcar para deletar a imagem antiga
          if (_oldAvatarUrl != null && _oldAvatarUrl!.isNotEmpty) {
            shouldDeleteOldImage = true;
            oldImageToDelete = _oldAvatarUrl;
          }
        }
      } else if (_currentAvatarUrl == null && _oldAvatarUrl != null && _oldAvatarUrl!.isNotEmpty) {
        // Usuário removeu a foto
        shouldDeleteOldImage = true;
        oldImageToDelete = _oldAvatarUrl;
      }

      // Atualizar no Firebase
      final updates = {
        'Name': _nameController.text.trim(),
        'age': age,
        'city': selectedCity,
        'state': selectedState,
        'finished_basic': true,
      };

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updates['avatar'] = avatarUrl;
      } else {
        updates['avatar'] = '';
      }

      await _database.child('Users').child(widget.local_id).update(updates);

      // ✅ NOVO: Deletar imagem antiga do Firebase Storage
      if (shouldDeleteOldImage && oldImageToDelete != null) {
        print('🗑️ Deletando imagem antiga...');
        await _storageService.deleteFile(oldImageToDelete);
      }

      _showSnackBar('Informações atualizadas com sucesso!', isError: false);
      await Future.delayed(Duration(milliseconds: 800));
      
      final updatedData = {
        'name': _nameController.text.trim(),
        'age': age,
        'city': selectedCity,
        'state': selectedState,
        'avatar': avatarUrl ?? '',
        'finished_basic': true,
      };

      Navigator.pop(context, updatedData);
        
    } catch (e) {
      print('Erro ao salvar: $e');
      _showSnackBar('Erro ao salvar alterações. Tente novamente.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continuar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
    },
      
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Informações Básicas',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Widget invisível para absorver foco
                Focus(
                  focusNode: _dummyFocus,
                  child: Container(width: 0, height: 0),
                ),
                
                // Foto de perfil
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceModal,
                        child: Container(
                          width: screenWidth * 0.35,
                          height: screenWidth * 0.35,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3B82F6).withOpacity(0.1),
                            border: Border.all(
                              color: Color(0xFF3B82F6).withOpacity(0.3),
                              width: 2,
                            ),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : _currentAvatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_currentAvatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_profileImage == null && _currentAvatarUrl == null)
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color(0xFF3B82F6),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceModal,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // Nome
                Text(
                  'Nome Completo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  decoration: InputDecoration(
                    hintText: 'Digite seu nome',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF9FAFB),
                  ),
                ),

                SizedBox(height: 20),

                // Idade
                Text(
                  'Idade',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                AgeTextField(
                  controller: _ageController,
                ),

                SizedBox(height: 20),

                // Estado
                Listener(
                  onPointerDown: (_) => _removeFocusCompletely(),
                  child: StateDropdown(
                    initialValue: selectedState,
                    onChanged: (value) {
                      _removeFocusCompletely();
                      setState(() {
                        selectedState = value;
                        selectedCity = null;
                      });
                      Future.delayed(Duration(milliseconds: 100), () {
                        _removeFocusCompletely();
                      });
                    },
                  ),
                ),

                SizedBox(height: 20),

                // Cidade
                Listener(
                  onPointerDown: (_) => _removeFocusCompletely(),
                  child: CityDropdown(
                    selectedState: selectedState,
                    initialValue: selectedCity,
                    onChanged: (value) {
                      _removeFocusCompletely();
                      setState(() {
                        selectedCity = value;
                      });
                      Future.delayed(Duration(milliseconds: 100), () {
                        _removeFocusCompletely();
                      });
                    },
                  ),
                ),

                SizedBox(height: 32),

                // Botão Salvar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Color(0xFF3B82F6).withOpacity(0.6),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Salvar Alterações',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ NOVO: Overlay de upload com progress
          if (_isSaving && _uploadProgress > 0)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: EdgeInsets.all(20),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: _uploadProgress,
                          color: Color(0xFF3B82F6),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Enviando: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    )
    );
  }
}