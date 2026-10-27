extends Node2D

var playernear: bool = false
var shop_scene = preload("res://scenes/shop_1.tscn")

var current_shop = null

func _ready() -> void:
	playernear = false

func _process(delta: float) -> void:
	if playernear == true:
		$Label.text = "Press C to open the shop!"
	else:
		$Label.text = "Shopkeeper"
		
	if Input.is_action_just_pressed("augment") and playernear == true:
		if current_shop == null:
			var shop_instance = shop_scene.instantiate()
			current_shop = CanvasLayer.new()
			current_shop.add_child(shop_instance)
			add_child(current_shop)

			var boost_bar = $/root/main/UI/MarginContainer/BoostBar
			if boost_bar:
				boost_bar.visible = false
		else:
			current_shop.show()
			var boost_bar = $/root/main/UI/MarginContainer/BoostBar
			if boost_bar:
				boost_bar.visible = false


func _on_area_2d_body_entered(body) -> void:
	if body.is_in_group("player"):
		playernear = true



func _on_area_2d_body_exited(body: Node2D) -> void:
	playernear = false
