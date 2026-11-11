import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';

/// Área 16:9 do vídeo demonstrativo do exercício.
///
/// Se o exercício tiver `videoUrl`, mostra a capa (quando existir) com o
/// botão de play e abre o vídeo no app/browser do aparelho. Sem vídeo,
/// exibe um espaço reservado elegante — o layout nunca quebra.
class ExerciseVideo extends StatelessWidget {
  const ExerciseVideo({super.key, required this.exercise});

  final ExerciseDef exercise;

  bool get _hasVideo => (exercise.videoUrl ?? '').trim().isNotEmpty;

  Future<void> _open(BuildContext context) async {
    final raw = exercise.videoUrl!.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A URL do vídeo deste exercício é inválida.'),
        ),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o vídeo neste aparelho.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o vídeo neste aparelho.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _VideoPlaceholderBackground(),
            if ((exercise.thumbnailUrl ?? '').trim().isNotEmpty)
              Image.network(
                exercise.thumbnailUrl!.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
              ),
            if (_hasVideo)
              Material(
                color: Colors.black.withValues(alpha: 0.32),
                child: InkWell(
                  key: const Key('exercise-video-open'),
                  onTap: () => _open(context),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 32,
                            color: AppTheme.textOnPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Assistir demonstração',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        size: 28,
                        color: AppTheme.textMuted,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vídeo demonstrativo em breve',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Você pode adicionar a URL do vídeo ao editar a ficha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textFaint,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholderBackground extends StatelessWidget {
  const _VideoPlaceholderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceLight, AppTheme.backgroundElevated],
        ),
      ),
    );
  }
}
