# EmpireCraft Tycoon

Tycoon de empreendedorismo e tecnologia para celular (Android), em **Godot 4.2** + GDScript.
Você monta uma empresa de dispositivos: contrata equipe, pesquisa tecnologias, projeta produtos,
fixa preços e disputa o mercado contra concorrentes, num jogo infinito.

Inspirado na linhagem dos tycoons de PC (Game Dev Tycoon, Devices Tycoon), redesenhado para toque:
poucas telas, alvos grandes, **automação nativa** (contratar até lotar, treinar todos, pesquisar tudo)
e economia pensada para sessões curtas.

## Estado atual (v0.2)
Loop jogável completo: **Equipe → Pesquisa → Produto → Lançamento → Vendas → Mercado**.
Veja [docs/DESIGN.md](docs/DESIGN.md) para as regras, a arquitetura e o roteiro.

## Rodando
```bash
godot --headless --editor --quit        # 1ª vez: gera o cache de classes (erros de autoload são esperados)
godot --headless --editor --quit        # 2ª passada deve sair limpa
godot --path .                          # abre o jogo (precisa de display)

# testes
godot --headless --path . --script res://tests/run_tests.gd   # simulação (sem UI)
godot --headless --path . res://tests/UISmoke.tscn            # interface
godot --headless --path . --script res://tests/bot_balance.gd -- 3   # bot joga 3 anos e imprime a economia
```

## APK
O GitHub Actions (`.github/workflows/build.yml`) roda os testes e gera o APK. O build mais recente fica
em **Releases → "Build mais recente"** (dá para baixar direto pelo celular).
Para jogar: baixe o APK e instale (é um APK de debug assinado com uma chave de debug).

## Estrutura
```
data/            definições do jogo em JSON (categorias, pesquisa, agências, eventos)
src/core/        simulação pura (Company, Market, Employee, Product, Rules) - sem nós, 100% testável
src/autoload/    Game (ponte), Clock (tempo), Saves (persistência)
src/ui/          interface montada por código (Palette, UI, Page, GameScreen, pages/)
tests/           testes da simulação, bot de balanceamento, teste de UI, gerador de capturas
```

## Instalação
Veja [docs/INSTALL.md](docs/INSTALL.md). APK: Releases → "Build mais recente".

## Novidades da v0.3
- **Estúdio de design** em 4 etapas (formato, acabamento, cor, medidas, hardware, recursos extras, sistema, fabricante) com 3D ao vivo.
- **Pesquisas de design**: Novos Formatos, Materiais Premium, Recursos Avançados.
- **Sistema operacional próprio** (nome, versões, foco, cor) ou licenciado (OpenX, Droidix, Lumen).
- **Terceirização**: Fabrix, Meridian, Titan Foundry ou fábrica própria (níveis 1-3); defeitos e recalls.
- **Acordos comerciais** (varejo, operadora, games, componentes, influenciadores).
- **Finanças**: demonstrativo por categoria, impostos, empréstimos, patrimônio.
- **Bolsa**: 5 concorrentes com valor de mercado, ações negociáveis e abertura de capital (IPO).
- Correção: a rolagem não volta mais ao topo quando a página atualiza.
