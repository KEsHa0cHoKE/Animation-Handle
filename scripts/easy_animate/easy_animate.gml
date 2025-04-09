// easy_animate by KEsHa_cHoKE

enum E_ANIM {
	FRAMES,
	FRAMES_OVERALL,
	TIME,
	TIME_OVERALL
}

///@desc Конструктор, отвечающий за анимацию
///@param {Asset.GMObject|Id.Instance|Struct} _id id объекта/инстанса/структура, переменные которого будут анимироваться
///@param {String|Array<String>} _varsStringToAnimate название В ФОРМАТЕ СТРОКИ переменной/переменных объекта, которые будут анимироваться. Рекомендуется использовать nameof() для добавления элементов в массив
function Anim(_id, _varsStringToAnimate) constructor
{
	#region Переменные
	
	// Таймсурс, управляющий воспроизведением анимации
	var_timesource = undefined //time_source_create(time_source_game, 1, time_source_units_frames, function(){})
	
	// Хранит состояние анимации
	
	var_state					= 0 // Стейт от 0 (не анимируется) до максимального кол-ва ключевых значений анимации
	var_state_pause_remembered	= undefined // Стейт, сохранённый перед паузой
	
	// Переменные, которые задаются при запуске
	var_anim_type				= undefined // E_ANIM-тип анимации (frames|frames_overall|time|time_overall)
	var_period					= undefined // Время анимации
	var_target_anim_curve		= undefined // Кривая
	var_values_array			= undefined // Ключевые значения к которым стремится анимируемая переменная
	
	// Хранит id экземпляра объекта, к которому привязан экземпляр конструктора
	var_instance				= undefined
	// Хранит названия анимируемых переменных в виде строки
	var_names_to_anim			= []
	
	// Переменные для контроля кривых анимации
	var_start_value				= undefined // Стартовое значение, от которого анимируется переменная до следующего стейта
	var_curve_percent			= 0 // Процент на кривой, на котором сейчас находится процесс перехода к следующему ключевому значению от 0 до 1
	var_curve_percent_speed		= undefined // Скорость прибавления значений к "проценту" кривой
	
	// Хранит в себе методы/функции, которые будут выполнены на указанных ключевых значениях анимации (опционально)
	var_callback_methods		= []
	// Хранит метод/функцию для использования в конце анимации
	var_callback_method_animEnd = undefined
	
	// Макрос на случай, если необходимо добавить метод к концу анимации
	#macro						  ANIM_END -1
	// Имя переменной в инстансе, куда будут добавлены анимируемые в данный момент переменные
	#macro						  __INSTANCE_ANIMATABLE_VARS_NAME "animatable_vars"
	
	#endregion
	
	
	
	#region Методы
	
		#region Чтение/запись переменных конструктора
		
		///@func met_vars_add(_id, _varsString)
		///@desc Добавляет переменную/массив переменных для их последующей анимации
		///@arg {Id.Instance} _id id экземпляра объекта, которому принадлежат переменные
		///@arg {String|Array<String>} _varsString имя/массив имен переменных для добавления
		static met_vars_add = function(_id, _varsString)
		{
			var_instance = _id
			
			if (!variable_instance_exists(var_instance, __INSTANCE_ANIMATABLE_VARS_NAME))
			{
				variable_instance_set(var_instance, __INSTANCE_ANIMATABLE_VARS_NAME, [])
			}
			
			if (!is_array(_varsString))
			{
				if (!is_string(_varsString))
				{
					show_error("easy_animate : met_vars_add -> Предоставленное значение/значения не являются НАЗВАНИЕМ переменной в формате строки(STRING). Используйте функцию nameof() для добавления переменных", true)
				}
				
				array_push(var_names_to_anim, _varsString)
				
				var _value = variable_instance_get(_id, _varsString)
			}
			else
			{
				if (!is_string(_varsString[0]))
				{
					show_error("easy_animate : met_vars_add -> Предоставленное значение/значения не являются НАЗВАНИЕМ переменной в формате строки(STRING). Используйте функцию nameof() для добавления переменных", true)
				}
				
				for (var i=0; i<array_length(_varsString); i++)
				{
					array_push(var_names_to_anim, _varsString[i])
					
					var _value = variable_instance_get(_id, _varsString[i])
				}
			}
		}
		
		///@func met_vars_clear()
		///@desc Очищает массив анимируемых переменных
		static met_vars_clear = function()
		{
			array_resize(var_names_to_anim, 0)
		}
		
		///@func met_vars_is_anim_active()
		///@desc Возвращает, воспроизводится ли анимация
		static met_vars_is_anim_active = function()
		{
			return (var_state > 0)
		}
		
		///@func met_vars_is_anim_paused()
		///@desc Возвращает, стоит ли анимация на паузе
		static met_vars_is_anim_paused = function()
		{
			return (!is_undefined(var_state_pause_remembered))
		}
	
		#endregion
		
		
		
		#region Операции с коллбеками
		
		///@func met_callback_set(_keyframe, _methodOrFunc)
		///@desc Устанавливает функцию/метод, который будет выполнен при достижении указанного целевого значения.
		/// Указанное целевое значение - номер ячейки массива с переданными ключевыми значениями для анимации.
		///@arg {Real} _keyframe номер ключевого значения. Если конец анимации то ANIM_END или -1
		///@arg {Function} _methodOrFunc функция/метод
		static met_callback_set = function(_keyframe, _methodOrFunc)
		{
			if (!is_callable(_methodOrFunc))
			{
				show_error("easy_animate : met_callback_set -> Аргумент не является методом/функцией", true)
			}
			
			if (_keyframe == ANIM_END)
			{
				var_callback_method_animEnd = method(undefined, _methodOrFunc)
				exit;
			}
			
			var_callback_methods[_keyframe] = method(undefined, _methodOrFunc)
		}
		
		///@func met_callback_delete(_keyframe)
		///@arg {Real} _keyframe номер ключевого значения. Если конец анимации то ANIM_END или -1
		///@desc Удаляет функцию/метод, привязанный к кадру анимации
		static met_callback_delete = function(_keyframe)
		{
			if (_keyframe == ANIM_END)
			{
				var_callback_method_animEnd = undefined
				exit;
			}
			
			if (_keyframe > array_length(var_callback_methods)-1)
			{
				show_error("easy_animate : met_callback_delete -> Попытка удалить значение, которое больше чем кол-во ключевых кадров анимации", true)
			}
			
			var_callback_methods[_keyframe] = undefined
		}
		
		///@func met_callback_clear()
		///@desc Сбрасывает ВСЕ установленные функции/методы
		static met_callback_clear = function()
		{
			array_resize(var_callback_methods, 0)
			
			var_callback_method_animEnd = undefined
		}
		
		#endregion
		
		
		
		#region Контроль анимации
		
			#region Вспомогашки
			
			///@func __met_add_animatable_vars_to_instance()
			///@ignore
			__met_add_animatable_vars_to_instance = function()
			{
				var _animVars = variable_instance_get(var_instance, __INSTANCE_ANIMATABLE_VARS_NAME)
				var _varNames = var_names_to_anim
			
				with {_animVars, _varNames} array_foreach(_varNames, function(_e, _i){
					show_debug_message($"var added {_e}")
					array_push(_animVars, _e)
				})
			}
		
			///@func __met_remove_animatable_vars_from_instance()
			///@ignore
			__met_remove_animatable_vars_from_instance = function()
			{
				var _animVars = variable_instance_get(var_instance, __INSTANCE_ANIMATABLE_VARS_NAME)
				var _varNames = var_names_to_anim
			
				with {_animVars, _varNames} array_foreach(_varNames, function(_e, _i){
					var _index = array_get_index(_animVars, _e)
				
					if (_index) != -1
					{
						show_debug_message($"var deleted {_e}")
						array_delete(_animVars, _index, 1)
					}
					else
					{
						show_debug_message("easy_animate : __met_remove_animatable_vars_from_instance -> Не найдено значение для удаления", true)
					}
				})
			}
			
			#endregion
		
		///@func met_control_start(_animType, _valuesArray, _period, _animCurve = ANIM_CURVE_LINEAR, _resetAllSpeeds = true)
		///@desc Запускает анимацию
		///@param {Real} _animType E_ANIM-тип анимации
		///@param {Array<Real>} _valuesArray массив ключевых значений для анимации
		///@param {Real} _period время анимации в установленной единице
		///@param {Asset.GMAnimCurve} _animCurve кривая анимации, по умолчанию ANIM_CURVE_LINEAR
		///@param {Bool} _resetAllSpeeds сбросить все скорости с предыдущей анимации
		static met_control_start = function(_animType, _valuesArray, _period, _animCurve = ANIM_CURVE_LINEAR, _resetAllSpeeds = true)
		{
			if (_resetAllSpeeds)
			{
				met_control_speed_reset()
			}
			
			if (!is_undefined(var_timesource))
			{
				call_cancel(var_timesource)
			}
			else
			{
				__met_add_animatable_vars_to_instance()
			}
			
			var_state = 1
			
			var_values_array = _valuesArray
			var_period = _period
			var_target_anim_curve = _animCurve
			var_anim_type = _animType
			var_start_value = variable_instance_get(var_instance, var_names_to_anim[0])
			var_curve_percent = 0
			
			__animate()
		}
		
		///@func met_control_stop()
		///@desc Принудительно завершает анимацию.
		/// Анимируемые переменные остаются в состоянии на момент принудительного завершения.
		static met_control_stop = function()
		{
			var_state = 0
			if (!is_undefined(var_timesource))
			{
				call_cancel(var_timesource)
			}
			
			met_control_speed_reset()
		}
		
		///@func met_control_pause()
		///@desc Ставит анимацию на паузу
		static met_control_pause = function()
		{
			var_state_pause_remembered = var_state
			if (!is_undefined(var_timesource))
			{
				call_cancel(var_timesource)
			}
			
			var_state = 0
		}
		
		///@func met_control_unpause()
		///@desc Снимает анимацию с паузы
		static met_control_unpause = function()
		{
			if (is_undefined(var_state_pause_remembered))
			{
				show_debug_message("easy_animate : met_control_unpause -> Анимация не на паузе!")
				exit;
			}
			
			var_state = var_state_pause_remembered
			
			var_state_pause_remembered = undefined
			
			__met_set_timer()
		}
		
		///@func met_control_speed_reset()
		///@desc Сбрасывает рассчитанные значения скорости
		static met_control_speed_reset = function()
		{
			var_anim_type				= undefined
			var_state_pause_remembered	= undefined
			
			var_values_array			= undefined
			var_curve_percent_speed		= undefined
			var_start_value				= undefined
			var_curve_percent			= 0
			
			var_period					= undefined
			var_target_anim_curve		= undefined
		}
	
		#endregion
		
		
		
		#region Обработка анимаций
			
			#region Вспомогательные методы (!!!НЕ ДЛЯ ИСПОЛЬЗОВАНИЯ!!!)
			
			///@func __met_next_state(_valuesArray)
			///@ignore
			static __met_next_state = function(_valuesArray)
			{
				if (!is_undefined(var_callback_methods))
				{
					if (
						(array_length(var_callback_methods)-1 >= var_state-1) &&
						(is_callable(var_callback_methods[var_state-1]))
					   )
					{
						method_call(var_callback_methods[var_state-1], [])
					}
				}
			
				if (++var_state > array_length(_valuesArray))
				{
					__met_remove_animatable_vars_from_instance()
					if (!is_undefined(var_timesource))
					{
						call_cancel(var_timesource)
						var_timesource = undefined
					}
					
					var_state = 0
					
					if (is_callable(var_callback_method_animEnd))
					{
						var_callback_method_animEnd()
					}
				}
			}
			
			///@func __met_set_timer()
			///@ignore
			static __met_set_timer = function()
			{
				var_timesource = call_later(1, time_source_units_frames, __animate)
			}
			
			///@func __met_set_vars_to_inst(_value)
			///@ignore
			static __met_set_vars_to_inst = function(_value)
			{
				for (var i=0; i<array_length(var_names_to_anim); i++)
				{
					if (is_struct(var_instance))
					{
						var_instance[$ var_names_to_anim[i]] = _value
					}
					else
					{
						variable_instance_set(var_instance, var_names_to_anim[i], _value)
					}
				}
			}
			
			///@func __met_get_value_from_animCurve(_percent, _animCurve)
			///@ignore
			static __met_get_value_from_animCurve = function(_percent, _animCurve)
			{
				var _channel = animcurve_get_channel(_animCurve, 0)
				var _val = animcurve_channel_evaluate(_channel, _percent)
				return _val
			}
			
			#endregion
			
			
		
		///@func __animate()
		///@desc Анимирует переменные по кривой
		///@ignore
		__animate = function()
		{
			if (var_state == 0) then exit;
			
			if (array_length(var_names_to_anim) < 1)
			{
				show_error("easy_animate : __animate -> Не заданы переменные для анимации в экземпляре конструктора. Воспользуйтесь методом met_vars_add для их добавления", true)
			}
			
			var _targetValue	= var_values_array[var_state-1]
			var _value
			var _curveValue
			
			if (is_undefined(var_curve_percent_speed))
			{
				switch (var_anim_type)
				{
					case E_ANIM.FRAMES:
						var_curve_percent_speed = 1/var_period
					break;
					
					case E_ANIM.FRAMES_OVERALL:
						var_curve_percent_speed = 1/(var_period/array_length(var_values_array))
					break;
					
					case E_ANIM.TIME:
						var_curve_percent_speed = 1/(var_period*game_get_speed(gamespeed_fps))
					break;
					
					case E_ANIM.TIME_OVERALL:
						var_curve_percent_speed = 1/(var_period*game_get_speed(gamespeed_fps)/array_length(var_values_array))
					break;
				}
			}
			
			
			
			var_curve_percent += var_curve_percent_speed
			_curveValue = __met_get_value_from_animCurve(var_curve_percent, var_target_anim_curve)
				
			_value = var_start_value+((_targetValue-var_start_value)*_curveValue)
			__met_set_vars_to_inst(_value)
			
			if (var_state > 0)
			{
				__met_set_timer()
			}
			
			if (var_curve_percent >= 1)
			{
				var_curve_percent = 1
					_curveValue = __met_get_value_from_animCurve(var_curve_percent, var_target_anim_curve)
				var_curve_percent = 0
				
				_value = var_start_value+((_targetValue-var_start_value)*_curveValue)
				__met_set_vars_to_inst(_value)
				
				var_start_value = variable_instance_get(var_instance, var_names_to_anim[0])
				__met_next_state(var_values_array)
			}
		}
		
		#endregion
	
	#endregion
	
	
	
	// Добавление переданных в экземпляр конструктора значений
	met_vars_add(_id, _varsStringToAnimate)
}

/*
anim_x = new Anim()
anim_y = new Anim()
anim_scale = new Anim()
animGroup_move_to_point = new AnimGroup(id, [
	[
		[ anim_x, E_ANIM.FRAMES_OVERALL, [50], 120, ANIM_CURVE_QUART ],
		[ anim_y, E_ANIM.FRAMES_OVERALL, [50], 120, ANIM_CURVE_QUART ]
	],
	[
		[ anim_scale, E_ANIM.FRAMES_OVERALL, [50], 120, ANIM_CURVE_QUART ]	
	]
])
*/


///@func AnimGroup(_id, _groupName, _animsArray)
///@param {Asset.GMObject|Id.Instance} _id
///@param {String} _groupName
///@param {Array<Array<Array<Any>>>} _animsArray
function AnimGroup(_id, _groupName, _animsArray) constructor
{
	
}


///@func anim_is_var_animating(_id, _varName)
///@desc Возвращает, анимируется ли переменная объекта в данный момент
///@param {Id.Instance|Asset.GMObject} _id
///@param {String} _varName
///@return {Bool}
function anim_is_var_animating(_id, _varName)
{
	if (!variable_instance_exists(_id, __INSTANCE_ANIMATABLE_VARS_NAME)) then return false
	
	var _animatableVarsArray = variable_instance_get(_id, __INSTANCE_ANIMATABLE_VARS_NAME)
	return (array_contains(_animatableVarsArray, _varName))
}