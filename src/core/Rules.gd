class_name Rules
extends RefCounted
## Constantes de balanceamento. Mexa aqui para ajustar a economia do jogo.

const VERSION := "0.6.0"
const VERSION_CODE := 8
const START_YEAR := 2010
const DAYS_IN_MONTH := 30
const DAYS_IN_YEAR := 360

const START_MONEY := 150000.0
const START_REPUTATION := 30.0
const START_RESEARCH_POINTS := 60.0
const BANKRUPT_LIMIT := -50000.0

# Escritório: capacidade por nível e custo para subir do nível i para i+1.
const OFFICE_CAPS := [2, 4, 7, 11, 16]
const OFFICE_COSTS := [20000.0, 60000.0, 150000.0, 400000.0]

const MAX_DEV_PRODUCTS := 3
const MAX_CANDIDATES_PER_PROFESSION := 10

const SALARY_BASE := 400.0
const SALARY_PER_POINT := 20.0
const RENT_BASE := 500.0
const RENT_PER_STAFF := 150.0

const TRAIN_COST_PER_POINT := 40.0
const TRAIN_RP_PER_POINT := 0.02

const SPEC_BUDGET_BASE := 160
const SPEC_AXIS_MAX := 100
const SPEC_STEP := 5

# Amortecimento do começo: custos fixos pela metade nos primeiros dias ou com escritórios pequenos
const EARLY_DAYS := 90
const EARLY_OFFICE_LEVEL := 2
const EARLY_FIXED_FACTOR := 0.5
# Piso de demanda: produto razoável (preço justo, qualidade >= 50% da esperada) vende ao menos isto por dia
const MIN_DAILY_DEMAND := 2.0

# Mercado
const OUTSIDE_OPTION := 1.0
const EXPECTATION_START := 35.0
const EXPECTATION_PER_DAY := 0.04
const EXPECTATION_MAX := 160.0
const MARKET_GROWTH_PER_DAY := 0.0006
