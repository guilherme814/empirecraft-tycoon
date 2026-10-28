class_name Employee
extends RefCounted

const ATTRS := ["craft", "pace", "insight"]

var id: int = 0
var emp_name: String = ""
var profession: String = "engineer"
var craft: int = 30     # Técnica: qualidade do trabalho técnico
var pace: int = 30      # Ritmo: velocidade de desenvolvimento
var insight: int = 30   # Visão: pesquisa e design
var morale: float = 80.0
var hired_day: int = 0

func total() -> int:
	return craft + pace + insight

func salary() -> float:
	return Rules.SALARY_BASE + float(total()) * Rules.SALARY_PER_POINT

func is_maxed() -> bool:
	return craft >= 100 and pace >= 100 and insight >= 100

func to_dict() -> Dictionary:
	return {"id": id, "name": emp_name, "prof": profession, "craft": craft, "pace": pace,
		"insight": insight, "morale": morale, "hired": hired_day}

static func from_dict(d: Dictionary) -> Employee:
	var e := Employee.new()
	e.id = int(d.get("id", 0))
	e.emp_name = str(d.get("name", "?"))
	e.profession = str(d.get("prof", "engineer"))
	e.craft = int(d.get("craft", 30))
	e.pace = int(d.get("pace", 30))
	e.insight = int(d.get("insight", 30))
	e.morale = float(d.get("morale", 80.0))
	e.hired_day = int(d.get("hired", 0))
	return e
