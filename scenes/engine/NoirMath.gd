class_name NoirMath
extends RefCounted
## Pure math helpers ported from Inkfall's engine/math.js so seeded layouts and the
## smoothstep easings match the originals. A small mulberry32 PRNG gives reproducible
## skylines, blood splats and bolts from the same integer seeds the stories use.

const MASK := 0xFFFFFFFF


static func lerp_f(a: float, b: float, p: float) -> float:
	return a + (b - a) * p


static func clamp01(p: float) -> float:
	return 0.0 if p < 0.0 else (1.0 if p > 1.0 else p)


static func smooth01(p: float) -> float:
	p = clamp01(p)
	return p * p * (3.0 - 2.0 * p)


## mulberry32: the exact PRNG Inkfall uses, so a story seed lays a scene out identically.
static func rand32(seed_value: int) -> NoirRng:
	return NoirRng.new(seed_value)


## quadratic bezier sampled into points (canvas quadraticCurveTo), inclusive of the end point.
static func quad_points(p0: Vector2, ctrl: Vector2, p1: Vector2, segments := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, segments + 1):
		var u := float(i) / float(segments)
		var iu := 1.0 - u
		out.append(iu * iu * p0 + 2.0 * iu * u * ctrl + u * u * p1)
	return out


class NoirRng extends RefCounted:
	var _a: int

	func _init(seed_value: int) -> void:
		_a = seed_value & NoirMath.MASK

	func nextf() -> float:
		_a = (_a + 0x6D2B79F5) & NoirMath.MASK
		var t := _imul(_a ^ (_a >> 15), (1 | _a) & NoirMath.MASK)
		t = ((t + _imul(t ^ (t >> 7), (61 | t) & NoirMath.MASK)) ^ t) & NoirMath.MASK
		return float((t ^ (t >> 14)) & NoirMath.MASK) / 4294967296.0

	func range_f(lo: float, hi: float) -> float:
		return lo + (hi - lo) * nextf()

	## low 32 bits of a 32x32 signed multiply (JS Math.imul), computed without 64 bit overflow.
	static func _imul(a: int, b: int) -> int:
		a &= NoirMath.MASK
		b &= NoirMath.MASK
		var lo := (a * (b & 0xFFFF)) & NoirMath.MASK
		var hi := (a * ((b >> 16) & 0xFFFF)) & 0xFFFF
		return (lo + (hi << 16)) & NoirMath.MASK
