///@desc пауза

if (animTs_move_x.met_vars_is_anim_paused())
{
	animTs_move_x.met_control_unpause()
	animTs_move_y.met_control_unpause()
}
else
{
	animTs_move_x.met_control_pause()
	animTs_move_y.met_control_pause()
}