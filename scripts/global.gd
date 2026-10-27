extends Node

enum Mode { GROUND, FLY }

var mode: Mode = Mode.GROUND

var total_coins = 0
var base_flight_speed: int = 800.0
var flight_shop_price: float = 100.0
var max_dashes: int = 2
var dashes: int = 2
