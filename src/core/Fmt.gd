class_name Fmt
extends RefCounted
## Formatação de números e datas para a interface.

static func money(v: float) -> String:
	var sign_str := "-" if v < 0.0 else ""
	var a := absf(v)
	if a >= 1.0e9:
		return "%s$ %.2f B" % [sign_str, a / 1.0e9]
	if a >= 1.0e6:
		return "%s$ %.2f M" % [sign_str, a / 1.0e6]
	if a >= 1.0e4:
		return "%s$ %.1f K" % [sign_str, a / 1.0e3]
	return "%s$ %s" % [sign_str, thousands(int(round(a)))]

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
