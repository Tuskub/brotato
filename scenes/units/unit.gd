extends Node2D
class_name Unit

@export var stats: UnitStats

@onready var visuals: Node2D = %Visuals
@onready var sprite: Node2D = %Sprite
@onready var animation: AnimationPlayer = $AnimationPlayer

