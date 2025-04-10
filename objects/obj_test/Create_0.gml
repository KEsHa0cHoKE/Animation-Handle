animTs_move_x = new AnimTs(id, nameof(x))
animTs_move_x.met_control_start(E_ANIM.TIME_OVERALL, [100, room_width-100], 2, ANIM_CURVE_EASE)
animTs_move_x.met_callback_set(0, function(){
	animTs_move_y.met_control_start(E_ANIM.TIME_OVERALL, [room_height/2-100, room_height/2+100], 1, ANIM_CURVE_EASE)
})
animTs_move_x.met_callback_set(ANIM_END, function(){
	animTs_move_x.met_control_start()
})

animTs_move_y = new AnimTs(id, nameof(y))
animTs_move_y.met_callback_set(ANIM_END, function(){
	animTs_move_y.met_control_start()
})

#region Struct AnimTs

ball = {
	x : 200,
	y : room_height/2,
	rad : 50,
	anim_y : new AnimTs(self, nameof(y)),
	
	event_draw : function()
	{
		draw_set_color(c_aqua)
		draw_circle(x, y, rad, false)
		draw_set_color(c_white)
	}
}
ball.anim_y.met_vars_set_inst(ball)
ball.anim_y.met_control_start(E_ANIM.TIME_OVERALL, [100, room_height-100], 1, ANIM_CURVE_EASE)
ball.anim_y.met_callback_set(ANIM_END, function(){
	ball.anim_y.met_control_start()
})

#endregion

#region Constructor AnimTs

///@func Circle
Circle = function() constructor
{
	x = room_width-200
	y = room_height/2
	rad = 50
	
	anim_y = new AnimTs(self, nameof(y))
	anim_y.met_control_start(E_ANIM.TIME_OVERALL, [100, room_height-100], 1, ANIM_CURVE_EASE)
	anim_y.met_callback_set(ANIM_END, function(){
		anim_y.met_control_start()
	})
	
	event_draw = function()
	{
		draw_set_color(c_green)
		draw_circle(x, y, rad, false)
		draw_set_color(c_white)
	}
}
circle = new Circle()

#endregion


#region AnimStep

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

//anim_move_x.met_control_start()

#endregion


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