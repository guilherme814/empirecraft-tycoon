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

Testes: `test_save_roundtrip` (ida e volta) e `test_old_save_compat` (save v2 mínimo carrega com padrões) em `tests/run_tests.gd`.

## Proteção dos saves
- A cada gravação, o save anterior vira `save_0.bak.json`. Se o principal estiver corrompido, o jogo carrega o backup.
- Antes de migrar um save de formato antigo, é criada uma cópia `save_0.v<N>.bak.json` (nunca sobrescrita).
- v4 → 0.4.1: novos campos `cash_start`, `cash_flow_last`, `cash_items`, `cash_items_last` (padrão: caixa atual / vazios).
- Empréstimo, bolsa e obras passam a ser movimentos de caixa fora do lucro (antes contavam como receita/despesa).

## Atualizador (OTA)
- CI publica `version.json` na release `latest-build` com versão, SHA-256 do APK e notas. Configurações → "Verificar atualização" compara com `Rules.VERSION`.
- O Android pede confirmação para instalar; o APK precisa ter o mesmo pacote e a mesma assinatura do instalado.
- Pendente: assinatura digital do manifesto e download/instalação dentro do app (exige plugin Android).
