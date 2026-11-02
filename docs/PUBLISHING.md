# Como publicar o Device Empire

O CI gera, a cada push na `main`, um APK de **debug** (instalável, assinado com chave de debug). Para a Google Play é preciso um pacote **assinado com a sua chave**.

## 1. Criar a chave de assinatura (uma vez só — guarde com segurança!)
```
keytool -genkeypair -v -keystore deviceempire.keystore -alias deviceempire \
  -keyalg RSA -keysize 2048 -validity 10000
```
Quem perde a chave não consegue mais atualizar o app na Play. Faça backup fora do GitHub.

## 2. Guardar nos Secrets do repositório (Settings → Secrets and variables → Actions)
- `ANDROID_KEYSTORE_BASE64` — saída de `base64 -w0 deviceempire.keystore`
- `ANDROID_KEYSTORE_ALIAS` — `deviceempire`
- `ANDROID_KEYSTORE_PASSWORD` — a senha escolhida

Com `ANDROID_KEYSTORE_BASE64` definido, o CI exporta o APK em modo **release** assinado com essa chave. Sem o segredo, continua gerando o APK de debug.

## 3. Lista de verificação antes de enviar à Play
- [ ] Versão e `version/code` atualizados (o teste do projeto confere se batem)
- [ ] Política de privacidade publicada (docs/PRIVACY.md)
- [ ] Ficha preenchida (docs/STORE_LISTING.md) e capturas de tela
- [ ] Declaração de segurança de dados: nenhum dado coletado
- [ ] Teste num aparelho real: tutorial, salvar/carregar, 30 min de jogo, rotação e botão voltar
- [ ] Faixa de teste interno na Play antes de produção

## 4. Observações
- A Play exige **AAB** para apps novos. Para gerar AAB o Godot precisa do modelo de build Android (Projeto → Instalar modelo de build Android) e `gradle_build/use_gradle_build=true` e `export_format=1` no preset. Isso ainda não está ativado; o APK serve para distribuição direta.
- Atualização dentro do app: hoje o jogo avisa e abre o download; instalar sem sair do app exige um plugin Android nativo e não está implementado.
