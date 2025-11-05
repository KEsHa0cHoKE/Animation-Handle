// by KEsHa_cHoKE

// Имя переменной в инстансе, куда будут добавлены анимируемые в данный момент переменные
#macro	__INSTANCE_ANIMATABLE_VARS_NAME		"__animatable_vars"
// Макрос на случай, если необходимо добавить метод к концу анимации
#macro	ANIM_END							-1

// Тип анимации
enum E_ANIM {
	FRAMES,
	FRAMES_OVERALL,
	TIME,
	TIME_OVERALL
}

///@desc Конструктор, отвечающий за анимацию на таймсурсах
///@param {Asset.GMObject|Id.Instance|Struct} _id id объекта/инстанса/структура, переменные которого будут анимироваться
///@param {String|Array<String>} _varsStringToAnimate название В ФОРМАТЕ СТРОКИ переменной/переменных объекта, которые будут анимироваться. Рекомендуется использовать nameof() для добавления элементов в массив
function AnimTs(_id, _varsStringToAnimate) constructor
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
	var_target_anim_curve		= ANIM_CURVE_LINEAR // Кривая
	var_values_array			= undefined // Ключевые значения к которым стремится анимируемая переменная
	
	// Хранит id экземпляра объекта, к которому привязан экземпляр конструктора
	inst						= undefined
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
	
	#endregion
	
	
	
	#region Методы
	
	
	#region Чтение/запись переменных конструктора
		
	///@func met_vars_add(_id, _varsString)
	///@desc Добавляет переменную/массив переменных для их последующей анимации
	///@arg {Id.Instance} _id id экземпляра объекта, которому принадлежат переменные
	///@arg {String|Array<String>} _varsString имя/массив имен переменных для добавления
	static met_vars_add = function(_id, _varsString)
	{
		inst = _id
			
		if (!is_struct(inst) && !variable_instance_exists(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
		{
			variable_instance_set(inst, __INSTANCE_ANIMATABLE_VARS_NAME, [])
		}
		else if (is_struct(inst) && !struct_exists(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
		{
			inst[$ __INSTANCE_ANIMATABLE_VARS_NAME] = []
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
		
	///@func met_vars_set_inst(_instOrStruct)
	///@desc Привязывает новую цель к конструктору (цель используется, чтобы изменять переменные объекта/структуры)
	static met_vars_set_inst = function(_instOrStruct)
	{
		inst = _instOrStruct
		
		if (!is_struct(inst) && !variable_instance_exists(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
		{
			variable_instance_set(inst, __INSTANCE_ANIMATABLE_VARS_NAME, [])
		}
		else if (is_struct(inst) && !struct_exists(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
		{
			inst[$ __INSTANCE_ANIMATABLE_VARS_NAME] = []
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
	
	///@func met_vars_get_anim_percent()
	///@desc Возвращает процент завершённости анимации (от 0 до 1)
	static met_vars_get_anim_percent = function() {
		return var_curve_percent
	}
	
	#endregion
		
		
		
	#region Операции с коллбеками
		
	///@func met_callback_set(_keyframe, _methodOrFunc, [_deleteAfterCall = false])
	///@desc Устанавливает функцию/метод, который будет выполнен при достижении указанного целевого значения.
	/// Указанное целевое значение - номер ячейки массива с переданными ключевыми значениями для анимации.
	///@param {Real} _keyframe номер ключевого значения. Если конец анимации то ANIM_END или -1
	///@param {Function} _methodOrFunc функция/метод
	///@param {Bool} _deleteAfterCall очистить коллбек после срабатываения (false по умолчанию)
	static met_callback_set = function(_keyframe, _methodOrFunc, _deleteAfterCall = false)
	{
		if (!is_callable(_methodOrFunc))
		{
			show_error("easy_animate : met_callback_set -> Аргумент не является методом/функцией", true)
		}
			
		if (_keyframe == ANIM_END)
		{
			var_callback_method_animEnd = [_methodOrFunc, _deleteAfterCall]
			exit;
		}
			
		var_callback_methods[_keyframe] = [_methodOrFunc, _deleteAfterCall]
	}
		
	///@func met_callback_delete(_keyframe)
	///@param {Real} _keyframe номер ключевого значения. Если конец анимации то ANIM_END или -1
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
	
	///@func __met_is_inst_exists()
	///@ignore
	static __met_is_inst_exists = function() {
		return (instance_exists(inst) || is_struct(inst))
	}
	
	///@func __met_add_animatable_vars_to_instance()
	///@ignore
	static __met_add_animatable_vars_to_instance = function()
	{
		if (!__met_is_inst_exists()) then exit;
		
		var _animVars = (is_struct(inst) ? 
		inst[$ __INSTANCE_ANIMATABLE_VARS_NAME] :
		variable_instance_get(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
				
		var _varNames = var_names_to_anim
		
		with {_animVars, _varNames} array_foreach(_varNames, function(_e, _i){
			array_push(_animVars, _e)
		})
	}
		
	///@func __met_remove_animatable_vars_from_instance()
	///@ignore
	static __met_remove_animatable_vars_from_instance = function()
	{
		if (!__met_is_inst_exists()) then exit;
		
		var _animVars = (is_struct(inst) ? 
		inst[$ __INSTANCE_ANIMATABLE_VARS_NAME] :
		variable_instance_get(inst, __INSTANCE_ANIMATABLE_VARS_NAME))
		
		var _varNames = var_names_to_anim
			
		with {_animVars, _varNames} array_foreach(_varNames, function(_e, _i){
			var _index = array_get_index(_animVars, _e)
				
			if (_index) != -1
			{
				array_delete(_animVars, _index, 1)
			}
			else
			{
				//show_debug_message("easy_animate : __met_remove_animatable_vars_from_instance -> Не найдено значение для удаления", true)
			}
		})
	}
			
	#endregion
	
	
	///@func met_control_start(_animType, _valuesArray, _period, _animCurve)
	///@desc Запускает анимацию
	///@param {Real} _animType E_ANIM-тип анимации
	///@param {Array<Real>} _valuesArray массив ключевых значений для анимации
	///@param {Real} _period время анимации в установленной единице
	///@param {Asset.GMAnimCurve} _animCurve кривая анимации
	static met_control_start = function(_animType = var_anim_type,
	_valuesArray = var_values_array,
	_period = var_period,
	_animCurve = var_target_anim_curve)
	{
		if (!__met_is_inst_exists()) then exit;
		
		
		if (!is_undefined(var_timesource))
		{
			call_cancel(var_timesource)
		}
		else
		{
			__met_add_animatable_vars_to_instance()
		}
			
		var_state = 1
			
		var_curve_percent_speed		= undefined
		var_state_pause_remembered	= undefined
			
		var_values_array = _valuesArray
		var_period = _period
		var_target_anim_curve = (is_undefined(_animCurve) ? ANIM_CURVE_LINEAR : _animCurve)
		var_anim_type = _animType
		var_start_value = variable_instance_get(inst, var_names_to_anim[0])
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
			var_timesource = undefined
		}
		
		__met_remove_animatable_vars_from_instance()
		
		var_state_pause_remembered = undefined
		var_curve_percent_speed	= undefined
	}
		
	///@func met_control_pause()
	///@desc Ставит анимацию на паузу
	static met_control_pause = function()
	{
		var_state_pause_remembered = var_state
		if (!is_undefined(var_timesource))
		{
			call_cancel(var_timesource)
			var_timesource = undefined
		}
			
		var_state = 0
	}
		
	///@func met_control_unpause()
	///@desc Снимает анимацию с паузы
	static met_control_unpause = function()
	{
		if (is_undefined(var_state_pause_remembered))
		{
			show_debug_message("easy_animate : met_control_unpause -> Анимация не на паузе")
			exit;
		}
			
		var_state = var_state_pause_remembered
		var_state_pause_remembered = undefined
			
		__met_set_timer()
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
			if (array_length(var_callback_methods) > var_state-1 && is_array(var_callback_methods[var_state-1]) &&
				is_callable(var_callback_methods[var_state-1][0]))
			{
				var_callback_methods[var_state-1][0]()
						
				// Если указано удалить коллбек после срабатывания
				if (var_callback_methods[var_state-1][1] == true)
				{
					met_callback_delete(var_state-1)
				}
			}
		}
			
		if (++var_state > array_length(_valuesArray))
		{
			__met_remove_animatable_vars_from_instance()
			if (!is_undefined(var_timesource))
			{
				call_cancel(var_timesource)
			}
			
			var_timesource = undefined	
			var_state = 0
					
			if ((!is_undefined(var_callback_method_animEnd)) && is_callable(var_callback_method_animEnd[0]))
			{
				var_callback_method_animEnd[0]()
						
				// Если указано удалить коллбек после срабатывания
				if (var_callback_method_animEnd[1] == true)
				{
					met_callback_delete(ANIM_END)
				}
			}
		}
	}
			
	///@func __met_set_timer()
	///@ignore
	static __met_set_timer = function()
	{
		if (!__met_is_inst_exists()) then exit;
		
		var_timesource = call_later(1, time_source_units_frames, __animate)
	}
			
	///@func __met_set_vars_to_inst(_value)
	///@ignore
	static __met_set_vars_to_inst = function(_value)
	{
		if (!__met_is_inst_exists()) then exit;
		
		for (var i=0; i<array_length(var_names_to_anim); i++)
		{
			if (is_struct(inst))
			{
				inst[$ var_names_to_anim[i]] = _value
			}
			else
			{
				variable_instance_set(inst, var_names_to_anim[i], _value)
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
		if (!__met_is_inst_exists()) then exit;
			
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
					var_curve_percent_speed = 1/var_period*array_length(var_values_array)
				break;
					
				case E_ANIM.FRAMES_OVERALL:
					var_curve_percent_speed = 1/var_period
				break;
					
				case E_ANIM.TIME:
					var_curve_percent_speed = 1/(var_period*game_get_speed(gamespeed_fps))*array_length(var_values_array)
				break;
					
				case E_ANIM.TIME_OVERALL:
					var_curve_percent_speed = 1/(var_period*game_get_speed(gamespeed_fps))
				break;
			}
		}
		
		var_curve_percent += var_curve_percent_speed
		
		
		
		_curveValue = __met_get_value_from_animCurve(var_curve_percent, var_target_anim_curve)
		
		var _path = path_add()
		path_set_closed(_path, false)
		path_add_point(_path, var_start_value, 1, 0)
		for (var i=0; i<array_length(var_values_array); i++)
		{
			path_add_point(_path, var_values_array[i], i+2, 0)
		}
		
		_value = path_get_x(_path, _curveValue)
		__met_set_vars_to_inst(_value)
		
		if (var_state > 0)
		{
			__met_set_timer()
		}
		
		
		var _newState = floor(path_get_y(_path, _curveValue))
		if (_newState > var_state)
		{
			__met_next_state(var_values_array)
		}
		
		path_delete(_path)
	}
		
		
	#endregion Обработка Анимаций
	
	
	#endregion Методы
	
	
	
	// Добавление переданных в экземпляр конструктора значений
	met_vars_add(_id, _varsStringToAnimate)
}



///@func anim_is_var_animating(_id, _varName)
///@desc Возвращает, анимируется ли переменная объекта в данный момент
///@param {Id.Instance|Asset.GMObject|Struct} _id
///@param {String} _varName
///@return {Bool}
function anim_is_var_animating(_id, _varName)
{
	if (!is_struct(_id) && !variable_instance_exists(_id, __INSTANCE_ANIMATABLE_VARS_NAME)) then return false
	if (is_struct(_id) && !struct_exists(_id, __INSTANCE_ANIMATABLE_VARS_NAME)) then return false
	
	var _animatableVarsArray = (is_struct(_id) ?
	_id[$ __INSTANCE_ANIMATABLE_VARS_NAME] :
	variable_instance_get(_id, __INSTANCE_ANIMATABLE_VARS_NAME))
	return (array_contains(_animatableVarsArray, _varName))
}