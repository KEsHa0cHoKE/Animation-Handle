///@desc пауза

if (anim_move_x.met_vars_is_anim_paused())
{
	anim_move_x.met_control_unpause()
}
else
{
	anim_move_x.met_control_pause()
}