class_name Cfg
extends RefCounted
## Lectura tipada de valores de diccionarios de configuración (JSON), donde todo es Variant.


static func num(d: Dictionary, key: String) -> float:
	var v: float = d[key]
	return v


static func integer(d: Dictionary, key: String) -> int:
	var v: float = d[key]
	return int(v)


static func flag(d: Dictionary, key: String) -> bool:
	var v: bool = d[key]
	return v
