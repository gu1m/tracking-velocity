import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Title('Termos de Uso'),
        _Body('Última atualização: abril de 2026'),
        SizedBox(height: 16),
        _Heading('1. Aceitação'),
        _Body(
          'Ao instalar ou utilizar o Tracking Velocidade você concorda com '
          'estes Termos. Se não concordar, desinstale o aplicativo.',
        ),
        _Heading('2. Descrição do serviço'),
        _Body(
          'O Tracking Velocidade registra automaticamente sua velocidade via '
          'GPS enquanto o serviço em segundo plano está ativo. Os registros '
          'são armazenados localmente e, opcionalmente, na nuvem (conta Premium). '
          'O aplicativo não é um sistema de navegação nem de alerta de velocidade.',
        ),
        _Heading('3. Uso adequado'),
        _Body(
          'Você se compromete a:\n'
          '• Usar o aplicativo apenas para finalidades lícitas;\n'
          '• Não utilizar os registros gerados para fins fraudulentos;\n'
          '• Respeitar a legislação de trânsito vigente;\n'
          '• Não tentar contornar limitações técnicas do serviço.',
        ),
        _Heading('4. Responsabilidade sobre os dados'),
        _Body(
          'Os registros de velocidade são gerados a partir do sinal GPS do '
          'dispositivo e podem apresentar variações por condições de sinal, '
          'obstrução ou imprecisão do hardware. O Tracking Velocidade não '
          'garante a aceitação dos registros como prova em processos administrativos '
          'ou judiciais — essa avaliação cabe às autoridades competentes.',
        ),
        _Heading('5. Plano gratuito (Free)'),
        _Body(
          'O plano gratuito oferece armazenamento local no dispositivo e '
          'exibição de anúncios. Funcionalidades avançadas (exportação, '
          'sincronização em nuvem, sem anúncios) estão disponíveis no plano Premium.',
        ),
        _Heading('6. Plano Premium'),
        _Body(
          'O plano Premium é cobrado mensalmente via Mercado Pago (R\$ 13,99/mês). '
          'A assinatura renova automaticamente até que seja cancelada. '
          'O cancelamento pode ser feito a qualquer momento no aplicativo '
          '(Ajustes → Assinatura → Cancelar) ou diretamente no Mercado Pago. '
          'Não há reembolso proporcional por dias não utilizados após o cancelamento.',
        ),
        _Heading('7. Propriedade intelectual'),
        _Body(
          'Todo o conteúdo do aplicativo (código, design, marca) é de '
          'propriedade do desenvolvedor. É proibida a reprodução ou '
          'distribuição sem autorização expressa.',
        ),
        _Heading('8. Limitação de responsabilidade'),
        _Body(
          'O serviço é fornecido "como está". Não nos responsabilizamos por '
          'danos diretos ou indiretos decorrentes do uso ou da impossibilidade '
          'de uso do aplicativo, incluindo perda de dados por falha de hardware '
          'ou sinal GPS.',
        ),
        _Heading('9. Alterações'),
        _Body(
          'Podemos atualizar estes Termos a qualquer momento. A continuidade '
          'do uso após a publicação de novas versões implica aceitação das '
          'mudanças.',
        ),
        _Heading('10. Contato'),
        _Body('Dúvidas: contato@trackingvelocidade.com.br'),
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
