// by KEsHa_cHoKE
// Анимация на time_source: простой режим + анимация по ключевым точкам (path)

#macro __ANIM_VARS_TAG 		"__animatable_vars"
#macro __ANIM_USE_DELTA 	false
#macro ANIM_END 			-1

enum ANIM_UNITS {
    FRAMES,
    SECONDS
}

/// @desc  Конструктор анимации: плавное изменение переменной к значению или по ключевым точкам
/// @param {id.instance, struct} target  Объект или структура для анимации
/// @param {string, array<string>} vars  Имя переменной или массив имён (используйте nameof())
function Anim(target, vars) constructor
{
    // ───────── Приватные данные ─────────
    private = {
        target: undefined,
        varNames: [],
        timeSource: undefined,
        
        active: false,
        paused: false,
        progress: 0,
        
        startVal: 0,
        endVal: 0,
        duration: 1,
        units: ANIM_UNITS.SECONDS,
        curve: AC_LINEAR,
        speed: undefined,
        
        // Path-режим (анимация по ключевым точкам)
        isPathMode: false,
        path: undefined,
        pathKeyframes: [],
        pathLastSegment: 1,  // Начинаем с Y=1 (стартовая точка)
        
        onFinish: undefined,
        deleteCallbackAfterUse: false,
        keyframeCallbacks: [],
        deleteKeyframeCallbacksAfterUse: []
    }
    
    
    
    // ───────── Публичный API ─────────
    
    ///@desc Запустить анимацию
    ///@param {Real|Array<Real>} endValue Целевое значение или массив ключевых точек
    ///@param {Real} duration Длительность (в кадрах или секундах)
    ///@param {Asset.GMAnimCurve} curve Кривая анимации (по умолчанию линейная)
    ///@param {Constant.ANIM_UNITS} units Единицы времени (по умолчанию SECONDS)
    ///@param {Bool} perKeyframe Если true и включён path-режим: duration применяется к каждому сегменту отдельно
    start = function(endValue, duration, curve = AC_LINEAR, units = ANIM_UNITS.SECONDS, perKeyframe = false)
    {
		// Ранний выход, если таргет невалиден или переменные не заданы
		if (!_isTargetValid() || array_length(private.varNames) == 0) exit
        
        // Определяем режим по типу endValue
        private.isPathMode = is_array(endValue) && array_length(endValue) > 1
        
        // Остановить предыдущую анимацию
        if (private.timeSource != undefined) call_cancel(private.timeSource)
        else _registerVars()
        
        // Сброс параметров
        private.active = true
        private.paused = false
        private.progress = 0
        private.speed = undefined
        
        private.duration = duration
        private.units = units
        private.curve = curve != undefined ? curve : AC_LINEAR
        private.startVal = _getTargetVarValue()
        
        if (private.isPathMode)
        {
            private.pathKeyframes = endValue
            private.pathLastSegment = 1
            _buildPath()
        }
        else
        {
            private.endVal = endValue
            _cleanupPath()
        }
        
        // Расчёт скорости
        var numSegments = private.isPathMode ? array_length(private.pathKeyframes) : 1
        var effectiveDuration = (perKeyframe && private.isPathMode) ? private.duration * numSegments : private.duration
        private.speed = (private.units == ANIM_UNITS.FRAMES) ? 
            1 / effectiveDuration : 
            1 / (effectiveDuration * game_get_speed(gamespeed_fps))
        
        _tick()
		
		return self;
    }
    
    ///@desc Остановить анимацию
    stop = function()
    {
        private.active = false
        private.paused = false
        if (private.timeSource != undefined) call_cancel(private.timeSource)
        private.timeSource = undefined
        _unregisterVars()
        _cleanupPath()
		
		return self;
    }
    
    ///@desc Поставить на паузу
    pause = function()
    {
        if (!private.active) exit
        private.paused = true
        if (private.timeSource != undefined) call_cancel(private.timeSource)
        private.timeSource = undefined
		
		return self;
    }
    
    ///@desc Снять с паузы
    resume = function()
    {
        if (!private.active || !private.paused) exit
        private.paused = false
        _tick()
		
		return self;
    }
    
    ///@desc Переключить паузу
    togglePause = function() 
    { 
        if (private.paused) resume()
        else pause()
			
		return self;
    }
    
    ///@desc Прогресс анимации (0..1)
    getProgress = function() { return private.progress }
    
    ///@desc Активна ли анимация?
    isActive = function() { return private.active }
    
    ///@desc На паузе ли анимация?
    isPaused = function() { return private.paused }
    
    ///@desc Коллбек по завершении анимации
	///@param {Function} callback
	///@param {Bool} deleteAfterCall
    onComplete = function(callback, deleteAfterCall = false)
    {
        if (!is_callable(callback)) show_error("Anim: onComplete() -> Ожидалась функция", true)
        private.onFinish = callback
        private.deleteCallbackAfterUse = deleteAfterCall
		
		return self;
    }
    
    clearOnComplete = function() { private.onFinish = undefined }
    
    ///@desc Коллбек для ключевого кадра (только path-режим)
    ///@param {Real|Constant.ANIM_END} keyframeIndex Индекс ключа (0..n-1) или ANIM_END для конца
    ///@param {Function} callback
    ///@param {Bool} deleteAfterCall
	onKeyframe = function(keyframeIndex, callback, deleteAfterCall = false)
    {
        if (!is_callable(callback)) show_error("Anim: onKeyframe() -> Ожидалась функция", true)
        if (keyframeIndex == ANIM_END)
        {
            private.onFinish = callback
            private.deleteCallbackAfterUse = deleteAfterCall
        }
        else
        {
            private.keyframeCallbacks[keyframeIndex] = callback
            private.deleteKeyframeCallbacksAfterUse[keyframeIndex] = deleteAfterCall
        }
		
		return self;
    }
    
	///@param {Real|Constant.ANIM_END} keyframeIndex description
    clearKeyframeCallback = function(keyframeIndex)
    {
        if (keyframeIndex == ANIM_END) private.onFinish = undefined
        else private.keyframeCallbacks[keyframeIndex] = undefined
			
		return self
    }
    
	///@param {Id.Instance|Struct} target Ссылка на инстанс или стракт
    set_target_inst = function (target) {
		private.target = target
		
		return self
	}
	
	///@param {Array<String>|String} vars Одно или несколько значений
	set_vars_to_anim = function (vars) {
		if (!is_array(vars)) private.varNames = [vars]
		else private.varNames = vars
	}
	
	
    
    // ───────── Приватные методы ─────────
    
    /// @ignore
    _isTargetValid = function() { return instance_exists(private.target) || is_struct(private.target) }
    
    /// @ignore
	_getTargetVarValue = function()
	{
	    // Безопасно: возвращаем 0, если переменные не заданы
	    if (!_isTargetValid() || array_length(private.varNames) == 0) return 0
	    return is_struct(private.target) ? private.target[$ private.varNames[0]] : variable_instance_get(private.target, private.varNames[0])
	}
    
    /// @ignore
	_setTargetVarValue = function(val)
	{
	    // Безопасно: выходим, если нечего анимировать
	    if (!_isTargetValid() || array_length(private.varNames) == 0) exit
	    for (var i = 0; i < array_length(private.varNames); i++)
	    {
	        if (is_struct(private.target)) private.target[$ private.varNames[i]] = val
	        else variable_instance_set(private.target, private.varNames[i], val)
	    }
	}
    
    /// @ignore
    _registerVars = function()
    {
        if (!_isTargetValid()) exit
        var arr = is_struct(private.target) ? private.target[$ __ANIM_VARS_TAG] : variable_instance_get(private.target, __ANIM_VARS_TAG)
        if (arr == undefined)
        {
            arr = []
            if (is_struct(private.target)) private.target[$ __ANIM_VARS_TAG] = arr
            else variable_instance_set(private.target, __ANIM_VARS_TAG, arr)
        }
        for (var i = 0; i < array_length(private.varNames); i++)
        {
            var name = private.varNames[i]
            if (!array_contains(arr, name)) array_push(arr, name)
        }
    }
    
    /// @ignore
    _unregisterVars = function()
    {
        if (!_isTargetValid()) exit
        var arr = is_struct(private.target) ? private.target[$ __ANIM_VARS_TAG] : variable_instance_get(private.target, __ANIM_VARS_TAG)
        if (arr == undefined) exit
        for (var i = array_length(private.varNames) - 1; i >= 0; i--)
        {
            var name = private.varNames[i]
            var idx = array_get_index(arr, name)
            if (idx != -1) array_delete(arr, idx, 1)
        }
    }
    
    /// @ignore
    _evalCurve = function(t, curve)
    {
        var ch = animcurve_get_channel(curve, 0)
        if (ch == undefined) return t
        return animcurve_channel_evaluate(ch, t)
    }
    
    /// @ignore
    _buildPath = function()
    {
        if (private.path != undefined) path_delete(private.path)
        private.path = path_add()
        path_set_closed(private.path, false)
        path_add_point(private.path, private.startVal, 1, 0)  // Y=1 — старт
        for (var i = 0; i < array_length(private.pathKeyframes); i++)
        {
            path_add_point(private.path, private.pathKeyframes[i], i + 2, 0)  // Y=2,3,4... — ключи
        }
    }
    
    /// @ignore
    _cleanupPath = function()
    {
        if (private.path != undefined) { path_delete(private.path); private.path = undefined }
        private.pathKeyframes = []
        private.pathLastSegment = 1
    }
    
    /// @ignore
    _triggerKeyframeCallback = function(index)
    {
        if (index >= 0 && index < array_length(private.keyframeCallbacks))
        {
            var cb = private.keyframeCallbacks[index]
            if (is_callable(cb))
            {
                cb()
                if (private.deleteKeyframeCallbacksAfterUse[index])
                {
                    private.keyframeCallbacks[index] = undefined
                    private.deleteKeyframeCallbacksAfterUse[index] = undefined
                }
            }
        }
    }
    
    /// @ignore
    _triggerEndCallback = function()
    {
        if (is_callable(private.onFinish))
        {
            private.onFinish()
            if (private.deleteCallbackAfterUse) private.onFinish = undefined
        }
    }
    
    /// @ignore
    _tick = function()
    {
        if (!private.active || private.paused || !_isTargetValid()) exit
        if (array_length(private.varNames) == 0) show_error("Anim: Не заданы переменные для анимации", true)
        
        var _dtMult = __ANIM_USE_DELTA ? (delta_time / game_get_speed(gamespeed_microseconds)) : 1
        private.progress += private.speed * _dtMult
        
        if (private.isPathMode)
        {
            // === PATH-РЕЖИМ: анимация по ключевым точкам ===
            var curveVal = _evalCurve(private.progress, private.curve)
            var newVal = path_get_x(private.path, curveVal)
            var currentY = path_get_y(private.path, curveVal)
            var currentSegment = floor(currentY)
            
            _setTargetVarValue(newVal)
            
            // Вызов коллбеков при переходе в новый сегмент
            while (currentSegment > private.pathLastSegment)
            {
                private.pathLastSegment++
                var kfIndex = private.pathLastSegment - 2  // Y=2 → keyframe 0
                if (kfIndex >= 0 && kfIndex < array_length(private.pathKeyframes))
                {
                    _triggerKeyframeCallback(kfIndex)
                }
            }
            
            if (private.progress < 1)
            {
                private.timeSource = call_later(1, time_source_units_frames, _tick)
            }
            else
            {
                _setTargetVarValue(private.pathKeyframes[array_length(private.pathKeyframes) - 1])
                private.active = false
                private.paused = false
                private.timeSource = undefined
                _unregisterVars()
                _cleanupPath()
                _triggerEndCallback()
            }
        }
        else
        {
            // === ПРОСТОЙ РЕЖИМ: анимация к одному значению ===
            var curveVal = _evalCurve(private.progress, private.curve)
            var newVal = private.startVal + (private.endVal - private.startVal) * curveVal
            _setTargetVarValue(newVal)
            
            if (private.progress < 1)
            {
                private.timeSource = call_later(1, time_source_units_frames, _tick)
            }
            else
            {
                _setTargetVarValue(private.endVal)
                private.active = false
                private.paused = false
                private.timeSource = undefined
                _unregisterVars()
                _triggerEndCallback()
            }
        }
    }
    
    
    
    // ───────── Инициализация ─────────
    if (!is_array(vars)) private.varNames = [vars]
    else private.varNames = vars
    private.target = target
}



///@desc Проверить, анимируется ли переменная у объекта/структуры
///@param {id|struct} obj Объект для проверки
///@param {string} varName Имя переменной
///@return {bool} true если переменная анимируется
function anim_is_active(obj, varName)
{
    if (!is_struct(obj) && !variable_instance_exists(obj, __ANIM_VARS_TAG)) return false
    if (is_struct(obj) && !struct_exists(obj, __ANIM_VARS_TAG)) return false
    var arr = is_struct(obj) ? obj[$ __ANIM_VARS_TAG] : variable_instance_get(obj, __ANIM_VARS_TAG)
    return array_contains(arr, varName)
}