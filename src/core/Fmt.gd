class_name Fmt
extends RefCounted
## Formatação de números e datas para a interface.

## Moeda brasileira: "R$ 1.234", "R$ 12,3 mil", "R$ 1,50 mi", "R$ 2,10 bi".
static func money(v: float) -> String:
	var sign_str := "-" if v < 0.0 else ""
	var a := absf(v)
	if a >= 1.0e9:
		return "%sR$ %s bi" % [sign_str, _dec(a / 1.0e9, 2)]
	if a >= 1.0e6:
		return "%sR$ %s mi" % [sign_str, _dec(a / 1.0e6, 2)]
	if a >= 1.0e4:
		return "%sR$ %s mil" % [sign_str, _dec(a / 1.0e3, 1)]
	return "%sR$ %s" % [sign_str, thousands(int(round(a)))]

static func _dec(x: float, digits: int) -> String:
	return (("%." + str(digits) + "f") % x).replace(".", ",")

static func dec(x: float, digits: int = 1) -> String:
	return _dec(x, digits)

## Com centavos (preço de ação): "R$ 12,34".
static func money_exact(v: float) -> String:
	var whole := int(floor(absf(v)))
	var cents := int(round((absf(v) - float(whole)) * 100.0))
	if cents >= 100:
		whole += 1
		cents = 0
	return "%sR$ %s,%02d" % ["-" if v < 0.0 else "", thousands(whole), cents]

static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

static func date(day: int) -> String:
	var year := Rules.START_YEAR + floori(float(day) / float(Rules.DAYS_IN_YEAR))
	var month := floori(float(day % Rules.DAYS_IN_YEAR) / float(Rules.DAYS_IN_MONTH)) + 1
	var d := day % Rules.DAYS_IN_MONTH + 1
	return "%02d/%02d/%d" % [d, month, year]
