class_name BoardBackdrop
extends BoardObject
## A full board backdrop. It fills the viewport and draws behind everything, so its art is built
## in board pixels (not design units) sized to the board. Subclasses override build() to assemble
## the skyline, alley, rooftop or room from Polygon2D and Line2D nodes.

func place() -> void:
	z_index = depth
	scale = Vector2.ONE
	position = Vector2.ZERO
	_refresh_visibility()
	build(board.size, board.ground_y)


## subclasses build their art here, sized to the board.
func build(_board_size: Vector2, _ground_y: float) -> void:
	pass
