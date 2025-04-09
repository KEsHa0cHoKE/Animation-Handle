// Создание экземпляра конструктора, который контролирует анимацию
anim_move_x = new AnimStep(id, nameof(x))
anim_pulse = new AnimStep(id, [nameof(image_xscale), nameof(image_yscale)])

// Устанавливаем смену цвета квадрата и запуск анимации пульсации при достижении ключевого значения
// (так как коллбек исполняется в контексте экземпляра конструктора, 
// то self будет областью видимости конструктора. 
// Поэтому используем other и/или with
// для доступа к области видимости вызывающего объекта)
anim_move_x.met_callback_set(0, function(){
	with (other)
	{
		image_blend = choose(c_purple, c_aqua, c_yellow, c_fuchsia, c_lime, c_orange, c_maroon, c_olive, c_teal)
		anim_pulse.met_control_start()
	}
})
anim_move_x.met_callback_set(1, function(){
	with (other)
	{
		image_blend = choose(c_purple, c_aqua, c_yellow, c_fuchsia, c_lime, c_orange, c_maroon, c_olive, c_teal)
		anim_pulse.met_control_start()
	}
})

// Устанавливаем коллбек на последний кадр, который снова запустит анимацию,
// закольцовывая её
anim_move_x.met_callback_set(ANIM_END, function(){
	other.anim_move_x.met_control_start()
})

anim_move_x.met_control_start()





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