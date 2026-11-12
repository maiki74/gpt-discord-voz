# GPT + Discord no mesmo áudio

Faz o ChatGPT (modo de voz no Brave) conversar com a galera do Discord, usando o seu microfone HyperX com filtro de ruído. Feito para **este PC**: HyperX QuadCast, fone G435, Brave Nightly, Discord e SteelSeries Sonar.

## Instalar (1 clique)

1. Dê dois cliques em **`INSTALAR.bat`**.
2. Se o Voicemeeter Potato ainda não estiver instalado, o instalador oficial abre. Clique em **Sim**, depois em **Install**, e **reinicie o PC**. A configuração continua sozinha quando o Windows ligar.
3. Se o Brave estiver aberto, feche ele quando o script pedir.
4. No Discord, em **Configurações → Voz e vídeo**:
   - **Microfone** = `Voicemeeter Out B1`
   - **Alto-falante** = `Voicemeeter VAIO3 Input`
5. No chatgpt.com, se pedir microfone, escolha `Voicemeeter Out B2`.

## Desinstalar (1 clique)

1. Dê dois cliques em **`DESINSTALAR.bat`**.
2. Feche o Brave se o script pedir.
3. No desinstalador do Voicemeeter, clique em **Sim** e depois em **Uninstall**. Reinicie o PC.
4. No Discord, volte o microfone para `SteelSeries Sonar - Microphone`.

## Quem escuta quem

| Quem fala | Você escuta (A1) | Galera escuta (B1) | GPT escuta (B2) |
|---|---|---|---|
| Você (HyperX, com filtro) | não | sim | sim |
| GPT (Brave) | sim | sim | **nunca** |
| Galera (Discord) | sim | **nunca** | sim |

- **B1** é o microfone `Voicemeeter Out B1`: é o que o Discord e os outros apps recebem.
- **B2** é o microfone `Voicemeeter Out B2`: é o que o ChatGPT recebe.
- Pra a galera parar de ouvir o Brave na hora, apague o **B1** da coluna **Voicemeeter Input** no Voicemeeter.

## O que o instalador muda

- Instala o Voicemeeter Potato (site oficial, com a assinatura conferida) e faz ele abrir junto com o Windows.
- No Voicemeeter: entrada 1 = HyperX com o filtro de ruído (Denoiser 5), saída A1 = G435, buffer 1024 e as rotas da tabela acima.
- No Windows: o som do Brave vai pro `Voicemeeter Input` e o microfone padrão vira `Voicemeeter Out B1`.
- No Brave: o microfone preferido vira `Voicemeeter Out B2`. Antes ele guarda um backup em `Preferences.bak-gpt-discord-voz`.
- Baixa o SoundVolumeView (NirSoft) em `%APPDATA%\gpt-discord-voz`, pra trocar os dispositivos de áudio por comando.
