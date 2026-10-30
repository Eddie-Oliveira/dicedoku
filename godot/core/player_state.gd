class_name PlayerState
extends RefCounted
## One seat's state. Parallel dice arrays: df faces, dk kind, dv value (0 = not rolled), du used, dh held.

var name: String
var pet: String
var grid: Array
var df: Array = []
var dk: Array = []
var dv: Array = []
var du: Array = []
var dh: Array = []
var rolls := Rules.ROLLS
var lk := false
var turn := 1
var mis := 0
var hints := 0
var gold := 0
var plc := 0
var done := false
var lost := false
var fin := 0
var bt: Array = []
var ward := 0
var shk := 0
var fxd := false
var pending: Array = []
## "" for a human seat, else the bot level: easy, normal or hard.
var bot := ""
## Turns in a row without a placement (normal bots start guessing at 3).
var stall := 0

func _init(name_: String, pet_: String, puz: Array, dice: Array) -> void:
	name = name_
	pet = pet_
	grid = puz.duplicate()
	df = dice.duplicate()
	for f in df:
		dk.append("std")

func active() -> bool:
	return not done and not lost

func score() -> int:
	return turn + 2 * mis

func held_count() -> int:
	var c := 0
	for h in dh:
		if h:
			c += 1
	return c

func used_any() -> bool:
	for u in du:
		if u:
			return true
	return false
