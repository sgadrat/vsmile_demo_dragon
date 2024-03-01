extends Tree


# Called when the node enters the scene tree for the first time.
func _ready():
	var root = create_item()
	#hide_root = true
	root.set_text(0, "Scenes")
	var child1 = create_item(root)
	child1.set_text(0, "Title screen")
	var child2 = create_item(root)
	child2.set_text(0, "Landia in space")
	var subchild1 = create_item(child2)
	subchild1.set_text(0, "Landia anim")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
