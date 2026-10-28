# EmpireCraft Tycoon: Design e arquitetura

## Pilares
1. **Decisões, não cliques.** Tudo que é repetitivo tem automação nativa (Preencher, Treinar todos, Pesquisar tudo).
2. **Sessões curtas, profundidade longa.** Dá para jogar 5 minutos; o mercado continua evoluindo (jogo infinito).
3. **O mercado é o adversário.** A qualidade esperada sobe com o tempo; parar de evoluir é perder.
4. **Toque primeiro.** Paisagem, alvos de 64-100 px, sem arrastar sliders (botões − / +), rolagem por toque.

## Loop
`Contratar → Pesquisar → Projetar (pontos de especificação) → Desenvolver → Lançar (preço) → Vendas → Reinvestir`

## Regras principais (ver `src/core/Rules.gd` e `data/*.json`)
- **Tempo:** 1 dia de jogo; 30 dias/mês; 360 dias/ano; começa em 2010. Folha e aluguel todo mês.
- **Funcionários:** 4 profissões (Engenheiro, Programador, Designer, Pesquisador), 3 atributos 0-100
  (Técnica, Ritmo, Visão). Ritmo → velocidade de desenvolvimento; Técnica → qualidade; Visão → pesquisa/design.
- **Produto:** distribui-se um orçamento de *pontos de especificação* entre eixos da categoria (ex.: Desempenho, Bateria).
  Retornos decrescentes (`pontos^0.7`); mais pontos = mais custo de produção.
  `qualidade = spec_score × (1+tecnologia) × fator_equipe × (1+design)`.
- **Vendas/dia** (modelo de participação): `unidades = mercado × A / (1 + ΣA_seus + ΣA_rivais)`, onde
  `A = (qualidade/expectativa)^3 × (preço_justo/preço)^2.2 × envelhecimento × impulso_de_lançamento × reputação`.
  Preço absurdo ou qualidade defasada derrubam as vendas.
- **Mercado:** expectativa de qualidade sobe 0,04/dia; mercado cresce com o tempo; sazonalidade (mês 11);
  tendências e crises por eventos; rivais lançam produtos continuamente.
- **Falência:** caixa abaixo de -US$ 50 mil no fechamento do mês.

## Arquitetura
- `src/core` não depende de nós nem de autoloads. `Company` é o estado + regras, serializável em JSON.
  Isso permite testar tudo em headless e rodar o **bot de balanceamento**.
- `Game` (autoload) segura a `Company` atual e emite sinais para a UI; `Clock` converte tempo real em dias;
  `Saves` grava JSON versionado de forma atômica (tmp + rename) e salva ao sair do app.
- UI por código: `Page` só reconstrói quando a *assinatura* da página muda (não destrói botões no meio de um toque);
  números vivos são atualizados no lugar (`live()`).
- Dados em `data/*.json`: balancear ou adicionar categorias/pesquisas não exige mexer em código.

## Balanceamento
`tests/bot_balance.gd` joga N anos com uma estratégia simples (3 seeds). Meta atual: caixa apertado nos 3 primeiros
meses, ~US$ 1 M ao fim do 1º ano e ~US$ 5 M ao fim do 3º para um jogador competente. Ajuste `Rules.gd`/`data/` e rode de novo.

## Roteiro
- **v0.3:** hardware profundo (térmica, bateria, yield de fábrica), componentes como itens pesquisáveis.
- **v0.4:** software/SO próprio com participação de mercado; lojas e logística por país.
- **v0.5:** bolsa/investimentos, aquisições de rivais, eventos com escolhas.
- **v0.6:** arte, sons, tutorial, i18n (pt-BR/en), conquistas (Google Play Games).
- **Ideias de diferencial (a decidir):** ver "Inovações" na conversa de design.
