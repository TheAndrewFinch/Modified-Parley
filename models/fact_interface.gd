@tool
class_name ParleyFactInterface
extends RefCounted


func evaluate(ctx: ParleyContext, values: Array) -> Variant:
	push_error(
		ParleyUtils.log.error_msg(
			'Fact not implemented (ctx:%s, values:%s)' % [ctx, values]
		)
	)
	return null


func available_values() -> Array[Variant]:
	return []
