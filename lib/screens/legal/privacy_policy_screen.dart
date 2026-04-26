import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Privacidade')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PolicyContent(),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Title('Política de Privacidade'),
        _Body('Última atualização: abril de 2026'),
        SizedBox(height: 16),
        _Heading('1. Quem somos'),
        _Body(
          'Tracking Velocidade é um aplicativo desenvolvido para registrar '
          'automaticamente a velocidade do usuário via GPS, permitindo que ele '
          'comprove sua velocidade em casos de autuações injustas.',
        ),
        _Heading('2. Dados que coletamos'),
        _Body(
          '• Dados de localização (GPS) — coletados em segundo plano somente '
          'enquanto o serviço de tracking está ativo.\n'
          '• Dados de conta — e-mail ou número de telefone utilizados no '
          'cadastro/login via Firebase Authentication.\n'
          '• Dados de uso — velocidade, distância percorrida e horários das viagens.',
        ),
        _Heading('3. Finalidade do tratamento'),
        _Body(
          'Os dados são utilizados exclusivamente para:\n'
          '• Gerar registros de velocidade que possam ser apresentados como '
          'prova pelo próprio usuário;\n'
          '• Gerenciar a conta e a assinatura;\n'
          '• Melhorar o serviço (dados agregados e anonimizados).',
        ),
        _Heading('4. Base legal (LGPD)'),
        _Body(
          'O tratamento de dados é realizado com base no consentimento do '
          'titular (Art. 7º, I da Lei 13.709/2018) e na execução de contrato '
          '(Art. 7º, V), quando aplicável à assinatura Premium.',
        ),
        _Heading('5. Compartilhamento de dados'),
        _Body(
          'Não vendemos nem compartilhamos seus dados pessoais com terceiros, '
          'exceto:\n'
          '• Mercado Pago — processamento de pagamentos (apenas dados '
          'necessários para a transação);\n'
          '• Firebase (Google) — autenticação e armazenamento de sessão;\n'
          '• Supabase — armazenamento dos registros de viagem.',
        ),
        _Heading('6. Retenção de dados'),
        _Body(
          'Seus dados são mantidos enquanto a conta estiver ativa. '
          'Após a exclusão da conta, todos os dados são removidos em até 30 dias.',
        ),
        _Heading('7. Seus direitos (LGPD Art. 18)'),
        _Body(
          'Você tem direito a:\n'
          '• Confirmar a existência do tratamento;\n'
          '• Acessar seus dados;\n'
          '• Corrigir dados incompletos ou desatualizados;\n'
          '• Solicitar anonimização, bloqueio ou eliminação;\n'
          '• Revogar o consentimento;\n'
          '• Excluir sua conta diretamente no aplicativo (Ajustes → Excluir conta).',
        ),
        _Heading('8. Segurança'),
        _Body(
          'Utilizamos criptografia em trânsito (HTTPS/TLS) e controle de '
          'acesso baseado em tokens JWT (Firebase ID Token) para proteger '
          'seus dados.',
        ),
        _Heading('9. Contato'),
        _Body(
          'Dúvidas ou solicitações sobre privacidade: '
          'privacidade@trackingvelocidade.com.br',
        ),
        SizedBox(height: 32),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: AppColors.textSecondary,
        ),
      );
}
