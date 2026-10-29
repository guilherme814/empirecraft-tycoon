class_name Rules
extends RefCounted
## Constantes de balanceamento. Mexa aqui para ajustar a economia do jogo.

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

# Mercado
const OUTSIDE_OPTION := 1.0
const EXPECTATION_START := 35.0
const EXPECTATION_PER_DAY := 0.04
const EXPECTATION_MAX := 160.0
const MARKET_GROWTH_PER_DAY := 0.0006

# Economia e eventos
const MARKET_VOLATILITY := 0.04
const CONSUMER_CONFIDENCE_MIN := 0.7
const CONSUMER_CONFIDENCE_MAX := 1.4
const SUPPLY_CHAIN_MIN := 0.7
const SUPPLY_CHAIN_MAX := 1.35
const INFLATION_MIN := 0.01
const INFLATION_MAX := 0.14

# Marketing e produto
const MARKETING_CHANNELS := ["social", "retail", "streaming", "influencer", "launch_event"]
const PRODUCT_TEST_TYPES := ["field", "beta", "usability", "focus_group"]
const MAX_FEEDBACK_MEMORY := 24
const MAX_TEST_HISTORY := 12
