extends SceneTree
## Bot de balanceamento: joga N anos com uma estratégia simples e imprime a evolução.
##   godot --headless --path . --script res://tests/bot_balance.gd -- 3

func _initialize() -> void:
	var years := 3
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		years = int(args[0])
	for seed_v in [1, 2, 3]:
		play(seed_v, years)
	quit(0)

func play(seed_v: int, years: int) -> void:
	var c := Company.new(seed_v)
	var peak := c.money
	print("=== seed %d ===" % seed_v)
	for d in years * 360:
		if d % 5 == 0:
			strategy(c)
		c.advance_day()
		if c.game_over:
			print("  FALIU no dia %d" % c.day)
			return
		if c.day % 90 == 0:
			peak = maxf(peak, c.money)
			print("  %s  caixa %-12s rep %3d  equipe %2d  prod.lançados %d  pesq.nv %d" % [Fmt.date(c.day), Fmt.money(c.money),
				int(c.reputation), c.staff.size(), c.released_products().size(), total_research(c)])

func total_research(c: Company) -> int:
	var t := 0
	for k in c.research_levels:
		t += int(c.research_levels[k])
	return t

func strategy(c: Company) -> void:
	for prof in ["engineer", "programmer"]:
		if c.staff_of(prof).size() < 2 and c.money > 40000.0:
			c.auto_fill(prof, 0, 30000.0)
	if c.staff_of("researcher").is_empty() and c.money > 40000.0:
		c.auto_fill("researcher", 0, 30000.0)
	if c.staff_of("designer").is_empty() and c.money > 120000.0:
		c.auto_fill("designer", 0, 80000.0)
	# upgrades de escritório quando o caixa permite
	for prof in ["engineer", "programmer", "researcher"]:
		var cost := c.office_upgrade_cost(prof)
		if cost > 0.0 and c.money > cost * 3.0 and c.staff_of(prof).size() >= c.capacity(prof):
			c.upgrade_office(prof)
	c.research_all(60000.0)
	for p in c.products.duplicate():
		if p.state == Product.STATE_READY:
			c.release(p.id)
		elif p.state == Product.STATE_RELEASED and c.day - p.release_day > 500:
			c.retire(p.id)
	if c.dev_products().is_empty() and c.money > 60000.0:
		var best := "phone"
		for cat in ["console", "laptop", "watch", "phone"]:
			if c.category_unlocked(cat) and c.money > float(GameData.category(cat).dev_cost) * 2.5 \
					and c.missing_professions(cat).is_empty():
				best = cat
				break
		c.create_product("", best, c.default_specs(best))
