import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

/// Tela de login. Sem Firebase configurado, opera em modo local
/// (email opcional registrado localmente). Quando o Firebase Auth estiver
/// conectado, basta plugar o fluxo aqui.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _entrando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final state = context.read<AppState>();
    setState(() => _entrando = true);
    // Firebase Auth (email/senha) pode ser conectado aqui. Por ora,
    // guardamos o email localmente e seguimos.
    await state.setUserEmail(_email.text.trim().isEmpty ? null : _email.text.trim());
    setState(() => _entrando = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.health_and_safety, color: AppTheme.primary, size: 34),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bem-vindo ao\nNutriCoach AI',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sua IA para emagrecimento, nutrição e academia.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail (opcional)',
                  prefixIcon: Icon(Icons.mail_outline, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senha,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.cloud_off_outlined, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo local ativo. Conecte o Firebase Auth para contas em nuvem.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _entrando ? null : _login,
                child: _entrando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.background),
                      )
                    : const Text('Entrar'),
              ),
              OutlinedButton(
                onPressed: _entrando ? null : _login,
                child: const Text('Continuar sem conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}