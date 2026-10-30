# Arquitetura do Device Empire

Este documento define a organização estrutural do projeto e as regras para evolução do código. O objetivo é manter a lógica de negócio estável, evitar acoplamento com a UI e garantir que mudanças futuras não quebram saves, balance e gameplay.

## 1. Objetivo da arquitetura

A arquitetura deve priorizar:

- separação clara entre domínio, regras, UI e persistência
- lógica de negócio em `src/core`, sem dependência de nós do Godot
- testes automatizados para regras e regressões
- compatibilidade de save com versionamento explícito
- evolução incremental sem misturar UI com simulação

## 2. Princípios fundamentais

### 2.1. Domínio puro em `src/core`
O código em `src/core` deve representar o modelo do jogo e suas regras, sem:

- referência direta a cenas
- referência direta a controles da UI
- acesso a autoloads para lógica de negócio
- regras que dependem de renderização ou eventos de engine

### 2.2. Camadas com dependências controladas
As dependências devem seguir este fluxo:

- `src/core` -> não depende de `src/ui`
- `src/ui` -> pode consumir classes do `src/core`
- `src/autoload` -> serve como ponte entre engine e runtime
- `data/*.json` -> define conteúdo e parâmetros, não lógica de execução

### 2.3. Estrutura estável por camada
Toda nova feature deve entrar na camada correta, e não “no meio do caminho”.

### 2.4. Save e balance são contratos
Qualquer mudança em:

- estrutura de dados
- modelo de empresa/produto/funcionário
- regras do mercado
- eventos ou economia

deve ser tratada como contrato de compatibilidade e validada com migração + testes.

## 2.5. Estado atual da estrutura (v0.4)

A estrutura da seção 3 é o **alvo**. Hoje o código está assim, e as regras de camada já valem:

```
src/autoload/   Game, Clock, Saves, Sfx           (ponte com a engine)
src/core/       Company, Product, Market, Stocks, Reviews, Feedback, Lab, Marketing, Chips,
                Loyalty, Rules, GameData, Fmt     (domínio + simulação, sem nós/UI)
src/gfx3d/      DeviceModel, RoundedSlab          (modelos 3D procedurais)
src/ui/         GameScreen, pages/*, widgets      (apresentação)
data/*.json     conteúdo e parâmetros
tests/          run_tests.gd (regras), UISmoke (interface), bot_balance.gd, Screenshots.gd
```

Mover arquivos para `domain/` e `simulation/` fica para quando o `Company.gd` for dividido; até lá,
**sistemas novos entram como classes estáticas em `src/core`** (como `Loyalty`, `Marketing`, `Lab`) que
operam sobre `Company`/`Product`, e a UI só chama essas funções.

### 2.6. Escritório 3D e lojas (v0.5)
- `OfficeLayout` (core, puro): planta automática, assentos, pontos de pausa/conversa e rotas retas pelas pistas.
- `gfx3d/OfficeScene`, `OfficeWorker`, `MeshBuilder`: só visual, sem autoload; a página chama `sync(company)`. Nada é gravado no save.
- `Stores` (core): abrir/editar/fechar lojas, vendas diárias e custo mensal; `StoreScene` é a prévia 3D (herda de `OfficeScene`).
- Dados: `data/countries.json`, `data/stores.json`.

## 3. Organização recomendada

```
src/
  autoload/
    Game.gd
    Clock.gd
    Saves.gd
    Sfx.gd

  core/
    domain/
      Company.gd
      Product.gd
      Employee.gd
      Market.gd
      Stocks.gd
      Deal.gd
      Rival.gd

    simulation/
      Economy.gd
      ResearchSystem.gd
      HiringSystem.gd
      SalesSystem.gd
      EventsSystem.gd

    rules/
      Rules.gd
      GameData.gd
      Fmt.gd

    persistence/
      SaveManager.gd
      SaveMigrator.gd

    validation/
      Validators.gd
      BalanceChecks.gd

  ui/
    screens/
      MainMenu.gd
      GameScreen.gd
      CompanyScreen.gd
      MarketScreen.gd
      ResearchScreen.gd

    components/
      Panels/
      Cards/
      Charts/
      Buttons/

  services/
    NotificationService.gd
    AudioService.gd

  scenes/
    MainMenu.tscn
    Game.tscn

  tests/
    run_tests.gd
    UISmoke.tscn
    bot_balance.gd
    core/
      test_company.gd
      test_market.gd
      test_product.gd
      test_save_migration.gd

data/
  categories.json
  research.json
  events.json
  deals.json
  etc...

docs/
  ARCHITECTURE.md
  SAVE_MIGRATIONS.md
  BALANCE.md
```

## 4. Responsabilidades por camada

### 4.1. `src/core/domain`
Responsável por modelos e entidades do jogo.

Deve conter:

- `Company`
- `Product`
- `Employee`
- `Market`
- `Stocks`
- demais estruturas de domínio

Regras:

- sem nodes da engine
- sem UI
- sem autoloads
- serialização explícita (`to_dict()` / `from_dict()`)
- dados mínimos necessários para o estado do jogo

### 4.2. `src/core/simulation`
Responsável pela lógica do loop do jogo.

Exemplos:

- cálculo de renda
- distribuição de vendas
- progresso de pesquisa
- contratação, turnover e produtividade
- eventos do mercado

Regras:

- operar sobre dados do domínio
- não conhecer cenas nem controles
- receber dados do sistema e retornar resultados calculados

### 4.3. `src/core/rules`
Responsável por valores imutáveis e configurações do jogo.

Exemplos:

- `Rules.gd`
- `GameData.gd`
- `Fmt.gd`

Regras:

- constantes de balance
- dados do jogo em JSON
- parâmetros genéricos e reutilizáveis

### 4.4. `src/core/persistence`
Responsável por salvar, carregar e migrar o estado do jogo.

Exemplos:

- serialização do save
- versionamento
- migração de schema
- compatibilidade em atualizações

### 4.5. `src/ui`
Responsável por apresentação e interação.

Exemplos:

- telas
- botões
- cards
- gráficos
- filtros e navegação

Regras:

- não decidir regras de negócio
- não reimplementa lógica já presente em `src/core`
- consulta o estado do jogo e dispara ações de sistema

### 4.6. `src/autoload`
Responsável por integrar o runtime do Godot com os sistemas do jogo.

Exemplos:

- `Game.gd`
- `Clock.gd`
- `Saves.gd`
- `Sfx.gd`

Regras:

- agir como ponte, não como lógica principal
- manter o setup mínimo do ambiente

## 5. Regras para qualquer nova feature

Toda feature nova deve seguir este fluxo:

1. modelar a entidade ou regra no domínio
2. definir serialização do estado
3. escrever teste de regressão
4. implementar a lógica de simulação
5. validar balance
6. conectar com UI
7. verificar compatibilidade de save
8. documentar o impacto

Se a feature não passar por esse fluxo, ela não entra no projeto.

## 6. Regras de save e compatibilidade

Qualquer mudança em estrutura de dado exige:

- atualização do schema
- versionamento explícito
- migração de save
- teste de carregamento de saves antigos
- documentação em `docs/SAVE_MIGRATIONS.md`

Principais regras:

- nunca remover campo sem migração
- nunca mudar significado de um campo existente sem versionar
- nunca assumir que save antigo tem o mesmo formato atual
- toda mudança em `to_dict()` deve ser acompanhada de `from_dict()`

## 7. Regras de balance e economia

O balance do jogo deve ser tratado como um contrato de gameplay.

Toda alteração em:

- `Rules.gd`
- `data/*.json`
- valores de renda, custo, pesquisa, reputação, demanda

precisa de:

- revisão de impacto no loop financeiro
- teste de economia e escala
- comparação de comportamento após mudanças significativas
- atualização da documentação de balance

## 8. Regras para testes

Os testes devem cobrir:

- lógica de produção e renda
- cálculo de mercado e concorrência
- pesquisa e desenvolvimento
- contratação e folha de pagamento
- eventos e efeitos de mercado
- serialização e migração de save

### Exemplo de política

- qualquer correção em core precisa de teste
- qualquer mudança em regras do mercado precisa de teste de regressão
- qualquer mudança em save precisa de teste de compatibilidade

## 9. Checklist de revisão de PR

Antes de mergear, todo PR deve confirmar:

- a feature entrou na camada correta
- o modelo foi serializado corretamente
- o save foi migrado, se necessário
- a UI não duplicou regras de negócio
- o balance foi revisto
- os testes foram atualizados
- a documentação foi atualizada

## 10. Regra de ouro

A arquitetura do projeto não é opcional.

Ela deve ser tratada como um contrato explícito para manter:

- estabilidade do jogo
- previsibilidade de evolução
- segurança de save
- menos regressões
- manutenção mais simples em futuras versões

## 11. Resumo prático

Se uma mudança não estiver em uma camada clara, ela está em lugar errado.
Se uma regra não é testada, ela não é confiável.
Se o estado do jogo não tem serialização compatível, ela quebra save.
Se a UI decide o comportamento, a arquitetura já falhou.

Esse conjunto de regras é o que mantém o projeto crescendo sem perder coerência.
