@tool
class_name ParleyActionInterface
extends RefCounted


func run(ctx: ParleyContext, values: Array) -> int:
	push_error(
		ParleyUtils.log.error_msg(
			'Action not implemented (ctx:%s, values:%s)' % [ctx, values]
		)
	)
	return FAILED
