extends Node
## Ponte entre a simulação (Company) e a interface. Guarda a empresa atual.

signal company_changed
signal ticked(day: int)
signal changed                       # o jogador fez uma ação (contratar, pesquisar...)
signal notice(text: String, kind: String)
signal ui_request(kind: String, pid: int)   # "launch" | "reviews": a tela principal abre o painel

var company: Company = null
var _last_autosave_day: int = 0

func new_game(company_name: String) -> void:
	company = Company.new()
	company.company_name = company_name if company_name.strip_edges() != "" else "Minha Empresa"
	company.add_log("Bem-vindo à %s! Contrate uma equipe e desenvolva seu primeiro produto." % company.company_name, "info")
	_attach()

func load_game() -> bool:
	var c: Company = Saves.load_company()
	if c == null:
		return false
	company = c
	_attach()
	return true

func _attach() -> void:
	_last_autosave_day = company.day
	if not company.log_added.is_connected(_on_log):
		company.log_added.connect(_on_log)
	if not company.review_ready.is_connected(_on_review):
		company.review_ready.connect(_on_review)
	company_changed.emit()

func _on_review(pid: int) -> void:
	ui_request.emit("reviews", pid)

func _on_log(text: String, kind: String, sfx: String) -> void:
	if sfx != "":
		Sfx.play(sfx)
	notice.emit(text, kind)

func advance_day() -> void:
	if company == null or company.game_over:
		return
	company.advance_day()
	var every: int = Saves.autosave_days
	if every > 0 and company.day - _last_autosave_day >= every:
		save()
	ticked.emit(company.day)

func save() -> void:
	if company != null:
		Saves.save_company(company)
		_last_autosave_day = company.day

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
