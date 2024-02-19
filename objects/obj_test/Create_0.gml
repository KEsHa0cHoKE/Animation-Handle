anim_click = new class_animation()
anim_click.met_vars_add(id,
[nameof(image_xscale), nameof(image_yscale)])

anim_click.met_callback_set(0, function(){
	show_message("МЕТОД1")
})
anim_click.met_callback_set(ANIM_END, function(){
	show_message("МЕТОД2")
	
	other.anim_click.met_callback_clear()
})