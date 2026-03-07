// lib/utils/permission_handler_util.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado da checagem de permissão
enum PermissionResult {
  granted,           // Permissão concedida → pode prosseguir
  denied,            // Negada agora (pode pedir de novo)
  permanentlyDenied, // Negada permanentemente → redirecionar para configurações
}

class PermissionUtil {
  /// Checa e solicita permissão para câmera ou galeria.
  /// Retorna [PermissionResult] com o status final.
  static Future<PermissionResult> checkAndRequest({
    required bool isCamera,
  }) async {
    if (isCamera) {
      return _handlePermission(Permission.camera);
    }

    if (Platform.isIOS) {
      return _handlePermission(Permission.photos);
    }

    // Android: verifica versão do SDK
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13+ → READ_MEDIA_IMAGES
      return _handlePermission(Permission.photos);
    } else {
      // Android ≤ 12 → READ_EXTERNAL_STORAGE
      return _handlePermission(Permission.storage);
    }
  }

  static Future<PermissionResult> _handlePermission(Permission permission) async {
    final status = await permission.status;

    // Já concedida → libera direto sem pedir de novo
    if (status.isGranted) return PermissionResult.granted;

    // Já negada permanentemente → não pede, vai direto para configurações
    if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;

    // Pede pela primeira vez (ou após negação simples)
    final result = await permission.request();

    if (result.isGranted) return PermissionResult.granted;
    if (result.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  /// Exibe o diálogo correto de acordo com o [PermissionResult].
  /// - [denied]: avisa que a permissão é necessária e oferece tentar de novo
  /// - [permanentlyDenied]: explica a situação e redireciona para configurações
  ///
  /// Retorna `true` se o usuário optou por tentar de novo (apenas para [denied]).
  static Future<bool> showPermissionDialog({
    required BuildContext context,
    required PermissionResult result,
    required String permissionLabel, // ex: 'câmera', 'galeria', 'armazenamento'
    required String usageReason,     // ex: 'para tirar fotos de perfil'
  }) async {
    if (result == PermissionResult.granted) return true;

    if (result == PermissionResult.permanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context: context,
        permissionLabel: permissionLabel,
        usageReason: usageReason,
      );
      return false;
    }

    // denied → oferece tentar de novo
    return await _showDeniedDialog(
      context: context,
      permissionLabel: permissionLabel,
      usageReason: usageReason,
    );
  }

  // ─── Diálogo: negada (pode tentar de novo) ───────────────────────────────
  static Future<bool> _showDeniedDialog({
    required BuildContext context,
    required String permissionLabel,
    required String usageReason,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3CD),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: Color(0xFFD97706), size: 32),
        ),
        title: Text(
          'Permissão de $permissionLabel necessária',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Precisamos de acesso à sua $permissionLabel $usageReason.\n\nDeseja conceder a permissão?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Não agora', style: TextStyle(color: Colors.grey[600])),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Conceder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Diálogo: negada permanentemente (vai para configurações) ─────────────
  static Future<void> _showPermanentlyDeniedDialog({
    required BuildContext context,
    required String permissionLabel,
    required String usageReason,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFE4E4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock, color: Color(0xFFDC2626), size: 32),
        ),
        title: Text(
          'Acesso à $permissionLabel bloqueado',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
            children: [
              TextSpan(text: 'Você bloqueou o acesso à $permissionLabel.\n\n'),
              const TextSpan(text: 'Para habilitar, vá em:\n'),
              const TextSpan(
                text: 'Configurações → Aplicativos → Permissões',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const TextSpan(text: '\n\ne ative a permissão manualmente.'),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Agora não', style: TextStyle(color: Colors.grey[600])),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings(); // Abre direto as configurações do app
            },
            icon: const Icon(Icons.settings, color: Colors.white, size: 18),
            label: const Text(
              'Abrir Configurações',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}