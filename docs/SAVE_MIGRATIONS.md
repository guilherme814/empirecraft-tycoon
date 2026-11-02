# Migrações de save

O save é um JSON (`Company.to_dict()`); `Company.SAVE_VERSION` marca o formato. Regras: nunca remover campo sem
migração, nunca mudar o significado de um campo, e todo campo novo precisa de **valor padrão** em `from_dict()`.
Saves de versão mais nova que o jogo são recusados (retorna `null`).

| Versão | Jogo | Mudança | Migração |
|---|---|---|---|
| 1 | 0.2 | Formato inicial | — |
| 2 | 0.3 | Ledger, empréstimo, histórico, acordos, SO próprio, fábrica, bolsa, rivais | campos novos com padrão |
| 3 | 0.4-wip | Avaliações (`rating`, `critic`, `reviews`), promessa de lançamento, marketing (`campaigns`, `awareness`), laboratório (`lab_jobs`, `flaws`, `tests`), chips, pedidos da equipe | campos novos com padrão |
| 4 | 0.4.0 | Lealdade à marca (`loyalty`, `loyalty_log`), macroeconomia do mercado (`sentiment`, `inflation`, `supply_chain`) | `loyalty` = 5, macro neutra (1.0 / 2,5% / 1.0) |
| 5 | 0.5.0 | Lojas próprias (`stores`: país, cidade, tamanho, fachada, equipe, vendas) | lista vazia |
| 6 | 0.6.0 | Identidade (`logo`) e decoração do escritório (`decor`) | logotipo e móveis padrão |

Saves antigos mantêm os rivais fictícios já gravados; jogos novos usam os rivais reais de `data/rivals.json`.

O escritório 3D não grava nada no save: é só visualização da equipe.

Testes: `test_save_roundtrip` (ida e volta) e `test_old_save_compat` (save v2 mínimo carrega com padrões) em `tests/run_tests.gd`.

## Proteção dos saves
- A cada gravação, o save anterior vira `save_0.bak.json`. Se o principal estiver corrompido, o jogo carrega o backup.
- Antes de migrar um save de formato antigo, é criada uma cópia `save_0.v<N>.bak.json` (nunca sobrescrita).
- v6 → 0.7.1: novo campo `sandbox` (padrão: falso). Ligado, caixa e pontos de pesquisa são repostos a um piso enorme a cada ação e a cada dia.
- v7 → v8 (0.7.2): novos campos `log_serial` (contador das notificações), `notif_seen` (última lida) e `own_os.look` (aparência do sistema próprio). Saves antigos usam padrões; entradas antigas do log ficam sem número e contam como lidas.
- v8 → v9 (0.8.0): rivais ganham `launches`, `star`, `rivalry`, `war_until`; 4 rivais novos (Nothing, OnePlus, Lenovo, Valve) entram no fim da lista ao carregar (índices antigos não mudam; ações e histórico preservados).
- v9 → 0.8.1: sem mudança no save; `data/research.json` ganhou o campo `area` (só apresentação).
- 0.8.2: sem mudança no save (erros de programação e resumo por país são calculados na hora).
- 0.8.3: sem mudança no save (logo nos aparelhos usa o logotipo já salvo).
- v9 → v10 (0.9.0): produtos ganham `stock`, `avg_cost`, `orders`, `auto`, `cover`, `store_ema`, `lost_ema`, `defects`; empresa ganha `mfr_busy`. Save antigo: produtos à venda recebem 30 dias de estoque (sem custo) ao carregar; os demais começam com 0.
- v10 → v11 (0.10.0): novos campos `tutorial` ({on, step, visited}) e `tips_seen`. Save antigo: tutorial desligado e nenhuma dica marcada como vista (as dicas de primeira visita aparecem uma vez).
- 0.11.0: sem mudança no save (a preferência do menu recolhido fica em user://settings.cfg).
- v4 → 0.4.1: novos campos `cash_start`, `cash_flow_last`, `cash_items`, `cash_items_last` (padrão: caixa atual / vazios).
- Empréstimo, bolsa e obras passam a ser movimentos de caixa fora do lucro (antes contavam como receita/despesa).

## Atualizador (OTA)
- CI publica `version.json` na release `latest-build` com versão, SHA-256 do APK e notas. Configurações → "Verificar atualização" compara com `Rules.VERSION`.
- O Android pede confirmação para instalar; o APK precisa ter o mesmo pacote e a mesma assinatura do instalado.
- Pendente: assinatura digital do manifesto e download/instalação dentro do app (exige plugin Android).
