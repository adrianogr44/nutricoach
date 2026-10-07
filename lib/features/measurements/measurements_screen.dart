import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/body_track.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Medidas corporais (abdominal, peito, braço, coxa, panturrilha) + fotos
/// da evolução.
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  MeasureType _type = MeasureType.abdominal;
  final _valor = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valor = double.tryParse(_valor.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) return;
    final state = context.read<AppState>();
    await state.addMeasurement(BodyMeasurement(date: DateTime.now(), type: _type, valueCm: valor));
    if (!mounted) return;
    setState(() => _valor.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📏 ${_type.label}: $valor cm registrado')),
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Foto da evolução',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accent),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(source: source, maxWidth: 900, imageQuality: 70);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final state = context.read<AppState>();
    await state.addPhoto(ProgressPhoto(
      id: const Uuid().v4(),
      date: DateTime.now(),
      dataUri: 'data:image/jpeg;base64,${base64Encode(bytes)}',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📸 Foto adicionada à evolução')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final latestByType = <MeasureType, double>{};
    for (final m in state.measurements) {
      latestByType[m.type] = m.valueCm;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('📏 Medidas e Evolução', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Circunferências',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MeasureType>(
            initialValue: _type,
            dropdownColor: AppTheme.surfaceLight,
            decoration: const InputDecoration(labelText: 'Medida'),
            items: [
              for (final t in MeasureType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (t) => setState(() => _type = t ?? MeasureType.abdominal),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (cm)', suffixText: 'cm'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: _save, child: const Text('Salvar')),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in MeasureType.values)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      latestByType[t]?.toStringAsFixed(1) ?? '—',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(t.label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
          ]),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: '📸 Fotos da evolução'),
              IconButton.filled(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_a_photo, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: const Color(0xFF06251A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.photos.isEmpty)
            const GlassCard(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Adicione fotos semanais para acompanhar sua evolução visual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: state.photos.length,
              itemBuilder: (context, i) {
                final photo = state.photos[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        base64Decode(photo.dataUri.replaceFirst('data:image/jpeg;base64,', '')),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                          ),
                        ),
                        child: Text(
                          '${photo.date.day}/${photo.date.month}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => state.removePhoto(photo.id),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}