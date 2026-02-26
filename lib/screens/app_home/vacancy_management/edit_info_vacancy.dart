// ✅ ARQUIVO OTIMIZADO - edit_info_vacancy.dart COM FIREBASE STORAGE
import 'package:dartobra_new/services/services_storage/service_storage.dart';
import 'package:dartobra_new/services/services_vacancy/vacancy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'components.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';


class EditInfoVacancy extends StatefulWidget {
  final bool isEditing;
  final String emailContact;
  final String phoneContact;
  final String localId;
  
  // PARÂMETROS PARA EDIÇÃO
  final String? vacancyId;
  final String? existingTitle;
  final String? existingProfession;
  final String? existingDescription;
  final String? existingState;
  final String? existingCity;
  final String? existingSalary;
  final String? existingSalaryType;
  final Map<dynamic, dynamic>? existingMedia;

  EditInfoVacancy({
    this.isEditing = false,
    required this.emailContact,
    required this.phoneContact,
    required this.localId,
    required this.vacancyId,
    required this.existingTitle,
    required this.existingProfession,
    required this.existingDescription,
    required this.existingState,
    required this.existingCity,
    required this.existingSalary,
    required this.existingSalaryType,
    required this.existingMedia,
  });

  @override
  _EditInfoVacancyState createState() => _EditInfoVacancyState();
}

class _EditInfoVacancyState extends State<EditInfoVacancy> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final VacancyService _vacancyService = VacancyService();
  final FirebaseStorageService _storageService = FirebaseStorageService(); // ✅ NOVO

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  // FocusNodes
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _salaryFocus = FocusNode();

  // Profissão e Tipo de Salário
  String? selectedProfession;
  String? selectedSalaryType;

  // Estado e Cidade
  String? selectedState;
  String? selectedCity;

  // Mídia
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  
  // LISTAS PARA MÍDIAS EXISTENTES (URLs)
  List<String> _existingImageUrls = [];
  List<String> _existingVideoUrls = [];
  
  // ✅ NOVO: URLs que devem ser deletadas
  List<String> _urlsToDelete = [];

  // Loading states
  bool _isUploading = false;
  bool _isLoadingData = false;
  String _uploadStatus = ''; // ✅ NOVO
  double _uploadProgress = 0.0; // ✅ NOVO

  // Lista de tipos de salário
  final List<String> salaryTypes = [
    'Diário',
    'Semanal',
    'Quinzenal',
    'Mensal',
    'Por empreitada',
    'A combinar',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    setState(() {
      _isLoadingData = true;
    });

    // Carregar dados nos controllers
    if (widget.existingTitle != null) {
      _titleController.text = widget.existingTitle!;
    }
    
    if (widget.existingDescription != null) {
      _descriptionController.text = widget.existingDescription!;
    }

    // Carregar profissão
    selectedProfession = widget.existingProfession;

    // Carregar estado e cidade
    selectedState = widget.existingState;
    selectedCity = widget.existingCity;

    // Carregar tipo de salário
    selectedSalaryType = widget.existingSalaryType;

    // Carregar salário
    if (widget.existingSalary != null && 
        widget.existingSalary != 'A combinar' &&
        widget.existingSalaryType != 'A combinar') {
      String salaryValue = widget.existingSalary!.replaceAll('R\$ ', '').replaceAll('.', '').replaceAll(',', '');
      _salaryController.text = salaryValue;
    }

    // Carregar mídias existentes
    if (widget.existingMedia != null) {
      if (widget.existingMedia!['images'] != null) {
        final imagesList = widget.existingMedia!['images'] as List;
        _existingImageUrls = imagesList.map((e) => e.toString()).toList();
      }
      
      if (widget.existingMedia!['videos'] != null) {
        final videosList = widget.existingMedia!['videos'] as List;
        _existingVideoUrls = videosList.map((e) => e.toString()).toList();
      }
    }

    setState(() {
      _isLoadingData = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    _salaryFocus.dispose();
    super.dispose();
  }

  // ✅ NOVO MÉTODO - Upload usando Firebase Storage com compressão
  Future<List<String>> _uploadAllMedia() async {
    List<String> uploadedUrls = [];
    int totalFiles = _selectedImages.length + _selectedVideos.length;
    int currentFile = 0;

    // Upload das imagens
    for (var image in _selectedImages) {
      currentFile++;
      setState(() {
        _uploadStatus = 'Enviando imagem $currentFile de $totalFiles...';
        _uploadProgress = 0.0;
      });

      String? url = await _storageService.uploadImage(
        file: image,
        folder: 'vacancies',
        userId: widget.localId,
        quality: 70,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (url != null) {
        uploadedUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar imagem $currentFile', Colors.red);
      }
    }

    // Upload dos vídeos
    for (var video in _selectedVideos) {
      currentFile++;
      setState(() {
        _uploadStatus = 'Enviando vídeo $currentFile de $totalFiles...';
        _uploadProgress = 0.0;
      });

      String? url = await _storageService.uploadVideo(
        file: video,
        folder: 'vacancies',
        userId: widget.localId,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (url != null) {
        uploadedUrls.add(url);
      } else {
        _showSnackBar('Erro ao enviar vídeo $currentFile', Colors.red);
      }
    }

    return uploadedUrls;
  }

  Future<void> _pickImages() async {
    try {
      int totalImages = _selectedImages.length + _existingImageUrls.length;
      if (totalImages >= 3) {
        _showSnackBar('Você já adicionou o máximo de 3 fotos', Colors.orange);
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        int remainingSlots = 3 - totalImages;
        List<File> imagesToAdd = images
            .take(remainingSlots)
            .map((img) => File(img.path))
            .toList();

        setState(() {
          _selectedImages.addAll(imagesToAdd);
        });

        if (images.length > remainingSlots) {
          _showSnackBar(
            'Apenas ${imagesToAdd.length} foto(s) foi(ram) adicionada(s). Limite máximo: 3 fotos',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      print('Erro ao selecionar imagens: $e');
      _showSnackBar('Erro ao selecionar imagens', Colors.red);
    }
  }

  Future<void> _pickVideo() async {
    try {
      int totalVideos = _selectedVideos.length + _existingVideoUrls.length;
      if (totalVideos >= 1) {
        _showSnackBar('Você já adicionou o máximo de 1 vídeo', Colors.orange);
        return;
      }

      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideos.add(File(video.path));
        });
      }
    } catch (e) {
      print('Erro ao selecionar vídeo: $e');
      _showSnackBar('Erro ao selecionar vídeo', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  // ✅ ATUALIZADO: Marcar para deletar depois
  void _removeExistingImage(int index) {
    String urlToRemove = _existingImageUrls[index];
    
    setState(() {
      _existingImageUrls.removeAt(index);
      _urlsToDelete.add(urlToRemove); // Marcar para deletar depois
    });
  }

  // ✅ ATUALIZADO: Marcar para deletar depois
  void _removeExistingVideo(int index) {
    String urlToRemove = _existingVideoUrls[index];
    
    setState(() {
      _existingVideoUrls.removeAt(index);
      _urlsToDelete.add(urlToRemove); // Marcar para deletar depois
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _validateFields() {
    if (selectedProfession == null ||
        _descriptionController.text.trim().isEmpty ||
        selectedState == null ||
        selectedCity == null) {
      _showSnackBar(
        'Por favor, preencha todos os campos obrigatórios',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  // ✅ MÉTODO OTIMIZADO - Salvar vaga com Firebase Storage
  Future<void> _saveVacancy() async {
    if (!_validateFields()) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Preparando arquivos...';
      _uploadProgress = 0.0;
    });

    try {
      // Upload das novas mídias
      List<String> newMediaUrls = await _uploadAllMedia();

      // Separar novas URLs por tipo
      List<String> newImageUrls = [];
      List<String> newVideoUrls = [];

      for (String url in newMediaUrls) {
        // Firebase Storage URLs contêm o tipo no path
        if (url.contains('.jpg') || url.contains('.jpeg') || 
            url.contains('.png') || url.contains('.webp')) {
          newImageUrls.add(url);
        } else if (url.contains('.mp4') || url.contains('.mov') || 
                   url.contains('.avi')) {
          newVideoUrls.add(url);
        }
      }

      // Combinar URLs existentes com as novas
      List<String> finalImageUrls = [..._existingImageUrls, ...newImageUrls];
      List<String> finalVideoUrls = [..._existingVideoUrls, ...newVideoUrls];

      // Processar salário
      String finalSalary = 'A combinar';
      if (selectedSalaryType != null) {
        if (selectedSalaryType == 'A combinar') {
          finalSalary = 'A combinar';
        } else if (_salaryController.text.trim().isNotEmpty) {
          finalSalary = '${_salaryController.text.trim()}';
        } else {
          finalSalary = selectedSalaryType!;
        }
      }

      setState(() {
        _uploadStatus = 'Salvando vaga...';
      });

      Map<String, dynamic> vacancyData = {
        'title': _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        'profession': selectedProfession,
        'state': selectedState,
        'city': selectedCity,
        'email_contact': widget.emailContact,
        'phone_contact': widget.phoneContact,
        'description': _descriptionController.text.trim(),
        'salary': finalSalary,
        'salary_type': selectedSalaryType,
        'local_id': widget.localId,
        'midia': {
          'images': finalImageUrls.isEmpty ? [] : finalImageUrls,
          'videos': finalVideoUrls.isEmpty ? [] : finalVideoUrls,
        },
      };

      if (widget.isEditing && widget.vacancyId != null) {
        // MODO EDIÇÃO: Atualizar vaga existente
        await _database.child('vacancy/${widget.vacancyId}').update(vacancyData);
        
        // ✅ NOVO: Deletar arquivos marcados APÓS salvar com sucesso
        if (_urlsToDelete.isNotEmpty) {
          setState(() {
            _uploadStatus = 'Limpando arquivos antigos...';
          });
          
          for (String url in _urlsToDelete) {
            await _storageService.deleteFile(url);
          }
        }
        
        _showSnackBar('Vaga atualizada com sucesso!', Colors.green);
      } else {
        // MODO CRIAÇÃO: Criar nova vaga
        vacancyData['created_at'] = DateTime.now().toIso8601String();
        vacancyData['status'] = 'Aberta';
        vacancyData['requests'] = [];
        vacancyData['views'] = {
          'owner_last_viewed': null,
          'request_views': {},
        };
        vacancyData['stats'] = {
          'total_views': 0, 
          'unique_viewers': [],
          'created_timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        await _database.child('vacancy').push().set(vacancyData);
        _showSnackBar('Vaga criada com sucesso!', Colors.green);
      }

      setState(() {
        _isUploading = false;
      });

      await Future.delayed(Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Erro ao salvar vaga: $e');
      setState(() {
        _isUploading = false;
      });
      _showSnackBar('Erro ao salvar vaga. Tente novamente.', Colors.red);
    }
  }

  void _viewImageFullscreen(File imageFile, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          images: _selectedImages,
          initialIndex: initialIndex,
          isVideo: false,
        ),
      ),
    );
  }

  void _viewVideoFullscreen(File videoFile, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          videos: _selectedVideos,
          initialIndex: initialIndex,
          isVideo: true,
        ),
      ),
    );
  }

  void _viewExistingImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  void _viewExistingVideoFullscreen(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('Carregando...'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          FocusScope.of(context).unfocus();
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Editar Vaga' : 'Nova Vaga',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    'Informações Básicas',
                    Icons.assignment,
                    true,
                  ),
                  SizedBox(height: 16),

                  ProfessionDropdown(
                    initialValue: selectedProfession,
                    onChanged: (value) {
                      setState(() {
                        selectedProfession = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    label: 'Título da Vaga (Opcional)',
                    hint: 'Ex: Vaga urgente para pedreiro experiente',
                    icon: Icons.title,
                  ),
                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _descriptionController,
                    focusNode: _descriptionFocus,
                    label: 'Descrição',
                    hint: 'Descreva os requisitos e responsabilidades...',
                    icon: Icons.description,
                    maxLines: 5,
                  ),
                  SizedBox(height: 16),

                  StateDropdown(
                    initialValue: selectedState,
                    onChanged: (value) {
                      setState(() {
                        selectedState = value;
                        selectedCity = null;
                      });
                    },
                  ),
                  SizedBox(height: 16),

                  CityDropdown(
                    selectedState: selectedState,
                    initialValue: selectedCity,
                    onChanged: (value) {
                      setState(() {
                        selectedCity = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),

                  _buildSalaryTypeDropdown(),
                  SizedBox(height: 16),

                  if (selectedSalaryType != null &&
                      selectedSalaryType != 'A combinar')
                    _buildSalaryField(),
                  if (selectedSalaryType != null &&
                      selectedSalaryType != 'A combinar')
                    SizedBox(height: 16),

                  SizedBox(height: 16),

                  _buildSectionTitle(
                    'Mídia (Opcional)',
                    Icons.photo_library,
                    false,
                  ),
                  SizedBox(height: 16),
                  _buildMediaUploadSection(),
                  SizedBox(height: 16),

                  // MÍDIAS EXISTENTES (URLs do Firebase)
                  if (_existingImageUrls.isNotEmpty) ...[
                    _buildExistingMediaGallery(
                      title: 'Imagens Atuais',
                      items: _existingImageUrls,
                      isVideo: false,
                    ),
                    SizedBox(height: 16),
                  ],

                  if (_existingVideoUrls.isNotEmpty) ...[
                    _buildExistingMediaGallery(
                      title: 'Vídeos Atuais',
                      items: _existingVideoUrls,
                      isVideo: true,
                    ),
                    SizedBox(height: 16),
                  ],

                  // NOVAS MÍDIAS SELECIONADAS (Files locais)
                  if (_selectedImages.isNotEmpty) ...[
                    _buildMediaGallery(
                      title: 'Novas Imagens',
                      items: _selectedImages,
                      isVideo: false,
                    ),
                    SizedBox(height: 16),
                  ],

                  if (_selectedVideos.isNotEmpty) ...[
                    _buildMediaGallery(
                      title: 'Novos Vídeos',
                      items: _selectedVideos,
                      isVideo: true,
                    ),
                    SizedBox(height: 16),
                  ],

                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveVacancy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isUploading
                            ? 'Salvando...'
                            : (widget.isEditing
                                  ? 'Salvar Alterações'
                                  : 'Criar Vaga'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // ✅ NOVO: Overlay melhorado com progresso detalhado
            if (_isUploading)
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
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B35),
                            ),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _uploadStatus,
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          if (_uploadProgress > 0) ...[
                            SizedBox(height: 8),
                            Text(
                              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Salário (Opcional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              FocusScope.of(context).unfocus();
            });
            _showSalaryTypeDialog();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFD1D5DB), width: 1),
              color: Color(0xFFF9FAFB),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey[400], size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedSalaryType ?? 'Selecione o tipo de salário',
                    style: TextStyle(
                      color: selectedSalaryType != null
                          ? Color(0xFF1F2937)
                          : Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSalaryTypeDialog() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusScope.of(context).unfocus();
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Tipo de Salário',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: salaryTypes.length,
                    itemBuilder: (context, index) {
                      final type = salaryTypes[index];
                      final isSelected = type == selectedSalaryType;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedSalaryType = type;
                            if (type == 'A combinar') {
                              _salaryController.clear();
                            }
                          });
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFF3B82F6).withOpacity(0.1)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: isSelected
                                    ? Color(0xFF3B82F6)
                                    : Colors.grey[600],
                                size: 22,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isSelected
                                        ? Color(0xFF3B82F6)
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF3B82F6),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildSalaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valor do Salário',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _salaryController,
            focusNode: _salaryFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'R\$ 0,00',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(
                Icons.attach_money,
                color: Color(0xFFFF6B35),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isRequired) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFFFF6B35), size: 22),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (isRequired) ...[
          SizedBox(width: 6),
          Text('*', style: TextStyle(color: Colors.red, fontSize: 18)),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: Color(0xFFFF6B35), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaUploadSection() {
    final int totalImages = _selectedImages.length + _existingImageUrls.length;
    final int totalVideos = _selectedVideos.length + _existingVideoUrls.length;
    
    final bool canAddMoreImages = totalImages < 3;
    final bool canAddVideo = totalVideos < 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUploadButton(
            Icons.photo_camera,
            canAddMoreImages
                ? 'Adicionar Fotos da Obra ($totalImages/3)'
                : 'Limite de 3 fotos atingido',
            canAddMoreImages ? _pickImages : () {},
            enabled: canAddMoreImages,
          ),
    
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Máximo: 3 fotos por vaga',
                    style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(10),
        color: enabled ? Colors.transparent : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: enabled ? Color(0xFFFF6B35) : Colors.grey[400],
                  size: 22,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: enabled ? Colors.grey[700] : Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // GALERIA DE MÍDIAS EXISTENTES (URLs)
  Widget _buildExistingMediaGallery({
    required String title,
    required List<String> items,
    required bool isVideo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.photo,
              color: Colors.blue[700],
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          _viewExistingVideoFullscreen(items[index]);
                        } else {
                          _viewExistingImageFullscreen(items[index]);
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[300]!, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isVideo
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      color: Colors.black,
                                      child: Center(
                                        child: Icon(
                                          Icons.videocam,
                                          size: 40,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.play_circle_fill,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ],
                                )
                              : Image.network(
                                  items[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          isVideo
                              ? _removeExistingVideo(index)
                              : _removeExistingImage(index);
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // GALERIA DE NOVAS MÍDIAS (Files locais)
  Widget _buildMediaGallery({
    required String title,
    required List<File> items,
    required bool isVideo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.photo,
              color: Color(0xFFFF6B35),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (isVideo) {
                          _viewVideoFullscreen(items[index], index);
                        } else {
                          _viewImageFullscreen(items[index], index);
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isVideo
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      color: Colors.black,
                                      child: Center(
                                        child: Icon(
                                          Icons.videocam,
                                          size: 40,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.play_circle_fill,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ],
                                )
                              : Image.file(items[index], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          isVideo ? _removeVideo(index) : _removeImage(index);
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Vídeo'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator(color: Color(0xFFFF6B35))
            : _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Erro ao carregar vídeo',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : SizedBox(),
      ),
    );
  }
}