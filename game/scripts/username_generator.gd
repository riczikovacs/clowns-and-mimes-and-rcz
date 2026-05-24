extends Node

## Procedural username generator. Pairs an adjective with a clown/mime noun.

const ADJECTIVES := [
	"Silent", "Painted", "Loud", "Floppy", "Crooked", "Bashful", "Velvet",
	"Hushed", "Ruffled", "Striped", "Glossy", "Pale", "Sneaky", "Whiskered",
	"Brittle", "Tipsy", "Polka", "Wobbly", "Crinkled", "Powdered",
]

const NOUNS := [
	"Bozo", "Coulrophobe", "Pierrot", "Harlequin", "Buffoon", "Jester",
	"Marceau", "Tramp", "Auguste", "Whiteface", "Carnie", "Pagliacci",
	"Punchinello", "Hopo", "Cake", "Honk", "Greasepaint", "Stripes",
	"Tear", "Glove",
]

func generate() -> String:
	var adj: String = ADJECTIVES[randi() % ADJECTIVES.size()]
	var noun: String = NOUNS[randi() % NOUNS.size()]
	var num := randi() % 1000
	return "%s%s%03d" % [adj, noun, num]
