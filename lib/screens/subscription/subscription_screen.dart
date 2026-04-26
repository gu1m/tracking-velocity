import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';
import '../../theme/app_theme.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final billing = context.watch<BillingService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Plano Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(user),
            const SizedBox(height: 24),
            const _PriceCard(price: BillingService.monthlyPriceBrl),
            const SizedBox(height: 24),
            const _Benefits(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: billing.isProcessing
                  ? null
                  : () => _checkout(context),
              icon: billing.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_rounded),
              label: Text(
                billing.isProcessing
                    ? 'Abrindo checkout…'
                    : 'Assinar por R\$ 13,99/mês',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            const _PaymentMethods(),
            const SizedBox(height: 24),
            const _FAQ(),
            const SizedBox(height: 16),
            if (user?.subscription == SubscriptionStatus.active)
              TextButton(
                onPressed: () => _cancel(context),
                child: const Text('Cancelar assinatura',
                    style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(AppUser? user) {
    final s = user?.subscription ?? SubscriptionStatus.expired;
    Color bg;
    Color fg;
    IconData icon;
    String title;
    String description;

    switch (s) {
      case SubscriptionStatus.active:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = Icons.verified_rounded;
        title = 'Premium ativo';
        description = user?.subscriptionRenewsAt != null
            ? 'Renova em ${DateFormat('dd/MM/yyyy').format(user!.subscriptionRenewsAt!)}.'
            : 'Sua assinatura está em dia.';
        break;
      case SubscriptionStatus.trial:
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primaryDark;
        icon = Icons.bolt_rounded;
        title = 'Período de avaliação';
        description = user?.subscriptionRenewsAt != null
            ? 'Você tem acesso completo até ${DateFormat('dd/MM/yyyy').format(user!.subscriptionRenewsAt!)}.'
            : 'Aproveite o teste grátis.';
        break;
      case SubscriptionStatus.pastDue:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        icon = Icons.warning_rounded;
        title = 'Pagamento pendente';
        description = 'Atualize sua forma de pagamento para continuar.';
        break;
      case SubscriptionStatus.canceled:
        bg = AppColors.textSecondary.withValues(alpha: 0.12);
        fg = AppColors.textSecondary;
        icon = Icons.history_rounded;
        title = 'Assinatura cancelada';
        description =
            'Você ainda tem acesso até o fim do período pago. Reative quando quiser.';
        break;
      case SubscriptionStatus.expired:
        bg = AppColors.danger.withValues(alpha: 0.12);
        fg = AppColors.danger;
        icon = Icons.lock_rounded;
        title = 'Sem assinatura ativa';
        description = 'Assine para continuar registrando suas viagens.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    )),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final ok = await context
        .read<BillingService>()
        .startCheckout(userId: user.uid);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o checkout.')),
      );
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
            'Você manterá acesso até o final do período pago. Tem certeza?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter ativa')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final preapprovalId = user.preapprovalId ?? '';
    if (!context.mounted) return;
    await context.read<BillingService>().cancelSubscription(
          userId: user.uid,
          preapprovalId: preapprovalId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assinatura cancelada.')),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final double price;
  const _PriceCard({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Plano Premium',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                letterSpacing: 1,
              )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('R\$ ',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
              Text(price.toStringAsFixed(2).replaceAll('.', ','),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  )),
              const Text(' /mês',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Cancele a qualquer momento. Sem fidelidade.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.gps_fixed_rounded, 'Tracking automático',
        'Em segundo plano, sem você precisar abrir o app.'),
    (Icons.history_rounded, 'Histórico ilimitado',
        'Guarde todas as suas viagens — sem limite de tempo.'),
    (Icons.file_download_rounded, 'Relatórios em Excel',
        'Exporte os dados de GPS para usar como prova em recursos de multa.'),
    (Icons.search_rounded, 'Busca avançada',
        'Filtre por data, horário, local e faixa de velocidade.'),
    (Icons.support_agent_rounded, 'Suporte prioritário',
        'Atendimento por WhatsApp em até 24 horas.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _items
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.$1,
                          color: AppColors.success, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          Text(e.$3,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded,
              color: AppColors.textSecondary, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pagamento seguro pelo Mercado Pago. Aceita PIX, cartão e boleto.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQ extends StatelessWidget {
  const _FAQ();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Perguntas frequentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        _FaqItem(
          q: 'O relatório serve como prova em uma multa?',
          a: 'Sim. O relatório traz seus dados de GPS minuto a minuto, '
              'incluindo horário, latitude, longitude e precisão — informações '
              'usadas como evidência documental em recursos de trânsito.',
        ),
        _FaqItem(
          q: 'Posso cancelar quando quiser?',
          a: 'Sim. O cancelamento é imediato e você mantém acesso até o '
              'final do período já pago.',
        ),
        _FaqItem(
          q: 'O app gasta muita bateria?',
          a: 'Não. O GPS só liga quando você passa de 10 km/h. '
              'Quando está parado ou andando, o consumo é praticamente zero.',
        ),
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(q,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(a,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }
}
