// Создание экземпляра конструктора, который контролирует анимацию
anim_move_x = new Anim(id, nameof(x))
anim_pulse = new Anim(id, [nameof(image_xscale), nameof(image_yscale)])


anim_move_x.met_control_start(E_ANIM.FRAMES_OVERALL, [room_width-sprite_width, sprite_width], 120, ANIM_CURVE_QUART)
anim_move_x.met_callback_set(ANIM_END, function(){
	met_control_start(E_ANIM.FRAMES_OVERALL, [room_width-var_instance.sprite_width, var_instance.sprite_width], 120, ANIM_CURVE_QUART)
})

r_struct = {
	a : 5,
}
r_struct.anim_a = new Anim(r_struct, "a")
r_struct.anim_a.met_control_start(E_ANIM.TIME, [25, 5], 5, ANIM_CURVE_EASE)


#region Перечисления доступных кривых для возможности переключения

curves = [
	ANIM_CURVE_CIRC,
	ANIM_CURVE_CUBIC,
	ANIM_CURVE_BACK,
	ANIM_CURVE_EASE,
	ANIM_CURVE_ELASTIC,
	ANIM_CURVE_EXPO,
	ANIM_CURVE_BOUNCE,
	ANIM_CURVE_FAST_TO_SLOW,
	ANIM_CURVE_MID_SLOW,
	ANIM_CURVE_QUART,
	ANIM_CURVE_LINEAR
]
target_curve = 0

#endregion