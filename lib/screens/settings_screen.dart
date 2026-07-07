import 'package:flutter/material.dart';
import '../core/theme.dart';

import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Pantalla de configuración - Ahora solo muestra que la app es local
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _borrarDatos(BuildContext context) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('¿Borrar todos los datos?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Esto eliminará la base de datos actual y restaurará los datos de prueba originales la próxima vez que abras la app. La app se cerrará.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('Sí, borrar todo')
          ),
        ],
      )
    );

    if (conf == true) {
      Directory dir = await getApplicationDocumentsDirectory();
      String path = join(dir.path, 'finanzas.db');
      await deleteDatabase(path);
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo Local (Offline)',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'La aplicación está configurada para funcionar 100% de manera local. Todos tus datos se guardan de forma segura en este dispositivo usando SQLite.\n\nNo se requiere conexión a internet ni a un servidor externo.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Restaurar Base de Datos'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => _borrarDatos(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
