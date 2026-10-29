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
