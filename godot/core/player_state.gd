class_name PlayerState
extends RefCounted
## One seat's state. Parallel dice arrays: df faces, dk kind, dv value (0 = not rolled), du used, dh held.

var name: String
var pet: String
var grid: Array
## Own solution and starting puzzle (every seat gets a transformed copy of the same puzzle).
var sol: Array
var puz: Array
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
## Blight dice still to turn into 1s when this seat locks.
var blight := 0
## Scribe quill: charges left and the tiles that show memo candidates.
var scribe := 0
var memo: Array = []

func _init(name_: String, pet_: String, sol_: Array, puz_: Array, dice: Array) -> void:
	name = name_
	pet = pet_
	sol = sol_.duplicate()
	puz = puz_.duplicate()
	grid = puz_.duplicate()
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
