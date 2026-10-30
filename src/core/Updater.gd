class_name Updater
extends RefCounted
## Atualização do jogo: compara versões e valida o manifesto publicado na Release do GitHub.
## O Android exige confirmação do jogador para instalar, e o APK novo precisa ter o mesmo pacote
## e a mesma assinatura do instalado (o sistema recusa se não tiver). Aqui só decidimos "há versão nova?".

const MANIFEST_URL := "https://github.com/guilherme814/empirecraft-tycoon/releases/download/latest-build/version.json"
const RELEASE_URL := "https://github.com/guilherme814/empirecraft-tycoon/releases/tag/latest-build"

## "0.4.2" -> [0, 4, 2]; inválido -> []
static func parse_version(v: String) -> Array:
	var out: Array = []
	for part in v.strip_edges().trim_prefix("v").split("."):
		if not part.is_valid_int():
			return []
		out.append(int(part))
	while out.size() < 3:
		out.append(0)
	return out

static func is_newer(remote: String, local: String) -> bool:
	var a := parse_version(remote)
	var b := parse_version(local)
	if a.is_empty() or b.is_empty():
		return false
	for i in 3:
		if int(a[i]) != int(b[i]):
			return int(a[i]) > int(b[i])
	return false

## Valida o manifesto: precisa de versão legível, URL https e SHA-256 de 64 hex. Devolve {} se inválido.
static func parse_manifest(text: String) -> Dictionary:
	var d: Variant = JSON.parse_string(text)
	if not (d is Dictionary):
		return {}
	var ver := str(d.get("version", ""))
	var url := str(d.get("apk_url", ""))
	var sha := str(d.get("sha256", "")).to_lower()
	if parse_version(ver).is_empty() or not url.begins_with("https://"):
		return {}
	if sha.length() != 64 or not sha.is_valid_hex_number(false):
		return {}
	return {"version": ver, "code": int(d.get("code", 0)), "apk_url": url, "sha256": sha,
		"min_save": int(d.get("min_save", 1)), "notes": str(d.get("notes", ""))}

static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

static func verify(bytes: PackedByteArray, expected_hex: String) -> bool:
	return sha256_hex(bytes) == expected_hex.to_lower()

