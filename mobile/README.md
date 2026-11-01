# AquaVoice — app nativo (Flutter)

Versão para **iPhone (iOS 14+)** e **Android (8.0 / API 26+)** do PWA AquaVoice
que está na raiz do repositório.

## Funcionalidades (paridade com o PWA)

| PWA | App |
|---|---|
| Círculo com onda mostrando % da meta | `WaveProgress` (CustomPainter animado) |
| Registro rápido 200/350/500 ml + personalizado | Aba **Consumo** |
| Meta diária, janela de horários e intervalo | Aba **Alarmes** |
| Gravação da voz para o alarme | Grava em WAV (máx. 30 s) com visualizador de onda |
| Chime sintetizado quando não há voz | `assets/sounds/chime.wav` (mesma melodia Dó-Mi-Sol-Dó) |
| Gráfico semanal Seg→Dom, lista do dia, limpar histórico | Aba **Histórico** |
| Sequência de dias batendo a meta | Selo no cabeçalho |
| Tela cheia "Hora de Beber Água!" (+250 ml ao parar) | `AlarmRingScreen` |
| IndexedDB / localStorage | SQLite (`sqflite`) / `shared_preferences` |

### O que melhora em relação ao PWA

- **Lembretes com o app fechado**: no PWA o alarme era um `setInterval` e só
  tocava com a página aberta. Aqui os lembretes são agendados no sistema.
- **Android**: notificação de alarme com *full-screen intent* — com a tela
  bloqueada o app abre por cima de tudo, direto na tela do alarme, e o som se
  repete até ser atendido.
- **iPhone**: a notificação toca a **sua voz** (o iOS limita sons de notificação
  a 30 s e não permite abrir uma tela sobre outros apps); ao tocar nela, abre a
  tela cheia do alarme tocando a voz em loop.
- Opção "Dispensar sem registrar" e botão "Testar alarme agora".

## Como rodar

Na raiz do repositório, dê dois cliques em **`rodar_simulador.command`** (ou
rode no Terminal). O script:

1. Instala o Flutter em `~/development/flutter` se não houver um instalado;
2. Gera as pastas nativas (`tool/setup_platforms.sh`) e aplica as configurações
   (iOS 14, Android API 26, permissões de microfone e notificação);
3. Abre o Simulador do iPhone e roda o app;
4. Aplica **hot reload automático** sempre que um arquivo em `lib/` mudar.

Para Android: `./rodar_simulador.command android` com o celular conectado e a
Depuração USB ativada.

Pré-requisito para iOS: Xcode instalado (App Store) com a plataforma iOS baixada.

### Pelo VS Code (recomendado para desenvolver e depurar)

1. Instale a extensão **Flutter** (o VS Code sugere ao abrir a pasta).
2. Abra a **pasta raiz do repositório** no VS Code.
3. Na barra inferior, clique no nome do dispositivo e escolha o **iPhone Simulator**.
4. Pressione **F5** (configuração "AquaVoice (debug)"). Breakpoints, inspeção de
   variáveis e hot reload ao salvar já vêm configurados.

### Pelo Xcode

O Xcode serve para a parte nativa (assinatura, permissões, instalar no iPhone
físico), mas não depura o código Dart. Depois de rodar o projeto uma vez, abra
`mobile/ios/Runner.xcworkspace` (ou `Runner.xcodeproj`) e use ▶︎ Run.

## Estrutura

```
lib/
  main.dart                  App, navegação e abertura da tela de alarme
  theme.dart                 Cores e fonte (Outfit) do PWA
  models/                    WaterRecord, AppSettings
  data/                      SQLite e preferências
  services/                  Notificações, gravação de voz, sons
  state/app_state.dart       Estado central (ChangeNotifier)
  utils/                     Regras puras: agenda de alarmes e estatísticas
  screens/                   Consumo, Alarmes, Histórico, Alarme tocando
  widgets/                   Onda, gráfico semanal, gravador, cartões
test/                        Testes das regras de agenda, estatísticas e widget
```

## Testes

```bash
cd mobile
flutter test
```

## Observações

- O iOS permite no máximo 64 notificações pendentes; o app agenda os próximos
  60 lembretes e reagenda sempre que é aberto.
- Para publicar na Play Store, o Google restringe a permissão de tela cheia
  (`USE_FULL_SCREEN_INTENT`) a apps de alarme/chamada; se não for aprovada, o
  lembrete continua funcionando como notificação comum.
