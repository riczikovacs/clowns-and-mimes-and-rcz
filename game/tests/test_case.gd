class_name TestCase
extends RefCounted

## Tiny test base. Tests inherit this and call assert_eq, assert_approx,
## assert_true. Failures are pushed to a static list the runner inspects after
## each test method.

static var failures: Array[String] = []

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("assert_true failed: %s" % message)

func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		failures.append("assert_false failed: %s" % message)

func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("assert_eq failed: %s actual=%s expected=%s" % [message, actual, expected])

func assert_approx(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append(
			"assert_approx failed: %s actual=%f expected=%f tol=%f" % [message, actual, expected, tolerance]
		)
