anim_scale = new class_animation()

anim_scale.met_vars_add(id,
[nameof(image_xscale), nameof(image_yscale)])

anim_scale.met_callback_set(0, function(){
	show_message("кейфрейм 0")
})

anim_scale.met_callback_set(ANIM_END, function(){
	show_message("конец анимации")
})