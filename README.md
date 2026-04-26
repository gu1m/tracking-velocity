# Tracking Velocidade

App mobile que registra a velocidade média do usuário (via GPS) toda vez
que ele ultrapassa 10 km/h, para servir como prova documental em recursos
de multas de velocidade injustas.

- **Plano:** R$ 13,99/mês via Mercado Pago.
- **Cores e layout:** inspirados no Waze (cyan vibrante + acentos laranja).
- **Plataformas:** Android e iOS (Flutter).
- **Privacy-first:** os dados ficam no aparelho. Só sobem para nuvem se o
  usuário pedir (ou se você ativar sync no roadmap).

## Estrutura do projeto

```
lib/
├── main.dart                      # Entry point + providers
├── theme/app_theme.dart           # Cores Waze e tema Material 3
├── models/                        # AppUser, Trip, SpeedRecord
├── services/
│   ├── auth_service.dart          # Firebase Auth (Google/Apple/E-mail/SMS)
│   ├── location_service.dart      # GPS + tracking em background
│   ├── storage_service.dart       # SQLite local (sqflite)
│   ├── billing_service.dart       # Mercado Pago (preapproval)
│   └── export_service.dart        # Geração de Excel para recursos
├── widgets/
│   ├── app_shell.dart             # Bottom navigation
│   ├── speed_dial.dart            # Velocímetro grande do dashboard
│   └── trip_card.dart             # Card de viagem da lista
└── screens/
    ├── onboarding/
    │   ├── onboarding_screen.dart
    │   ├── login_screen.dart
    │   ├── email_login_screen.dart
    │   ├── phone_login_screen.dart
    │   └── permissions_screen.dart
    ├── home/home_screen.dart           # Dashboard com velocímetro e status
    ├── history/
    │   ├── history_screen.dart         # Lista + busca rápida
    │   ├── search_filter_screen.dart   # Filtros avançados
    │   └── trip_detail_screen.dart     # Detalhes + gráfico + exportar
    ├── subscription/subscription_screen.dart
    └── settings/settings_screen.dart
```

## Como rodar

1. Instale o Flutter SDK 3.19+: https://docs.flutter.dev/get-started/install
2. No diretório do projeto:
   ```bash
   flutter pub get
   flutter run
   ```

## Configurações necessárias antes de publicar

### 1. Firebase (autenticação)

- Crie um projeto em https://console.firebase.google.com
- Habilite os providers: Google, Apple, Email/Password, Phone
- Rode `flutterfire configure` para gerar `firebase_options.dart`
- Descomente a linha `Firebase.initializeApp()` em `main.dart`
- Substitua os mocks em `auth_service.dart` pelas chamadas reais do
  `firebase_auth` (cada método tem um `// TODO`)

### 2. Mercado Pago (assinatura recorrente)

- Crie sua conta de developer em https://www.mercadopago.com.br/developers
- Crie um plano de preapproval com R$ 13,99/mês
- Implemente um backend (Cloud Functions, por exemplo) com o endpoint
  `POST /billing/mercadopago/subscribe` que:
  - Cria a preapproval para o usuário (passando o e-mail)
  - Devolve o `init_point` do Mercado Pago
- Configure o webhook do Mercado Pago para o seu backend, atualizando o
  `subscription_status` do usuário quando vier `authorized`, `paused` ou
  `cancelled`
- Atualize a constante `_subscriptionEndpoint` em `billing_service.dart`

### 3. Permissões e tracking em background

- **Android:** já configurado em `android/app/src/main/AndroidManifest.xml`
  (FOREGROUND_SERVICE_LOCATION + ACCESS_BACKGROUND_LOCATION).
- **iOS:** já configurado em `ios/Runner/Info.plist` (UIBackgroundModes
  com `location`).
- Importante: na Google Play, justifique o uso de
  `ACCESS_BACKGROUND_LOCATION` no formulário de Data Safety — explique
  que é necessário para registrar a velocidade do usuário sem que ele
  precise abrir o app.

### 4. Ícones e splash screen

- Coloque seus assets em `assets/images/`
- Use `flutter_launcher_icons` para gerar os ícones
- Use `flutter_native_splash` para a splash com a cor `#33CCFF`

## Próximos passos sugeridos

- [ ] Implementar de fato a leitura do `Geolocator.getPositionStream` no
      `LocationService` (hoje está mockado para a demo)
- [ ] Integrar `flutter_background_service` para Android/iOS
- [ ] Backend para gerenciar assinatura no Mercado Pago + webhook
- [ ] Backup opcional dos registros na nuvem (recurso premium)
- [ ] Tela de "exportar todas as minhas viagens" (mês inteiro)
- [ ] Notificação ao ultrapassar limite de velocidade configurado pelo usuário

## Fluxo do usuário (UX)

1. Abre o app pela primeira vez → onboarding em 3 telas
2. Escolhe método de login (Google, Apple, E-mail ou Telefone)
3. Aceita as permissões de localização em background
4. Pronto. O app passa a registrar automaticamente toda vez que
   o usuário ultrapassar 10 km/h.
5. Quando precisar contestar uma multa: abre o histórico, filtra por
   data/hora/local, exporta o Excel e anexa ao recurso.

## Licença

Proprietário. Todos os direitos reservados.
