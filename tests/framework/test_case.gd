# Base class for unit tests. Methods named test_* are run by tests/framework/test_runner.gd.
# Provides assertion helpers; failures are collected, not thrown.
# Related: tests/framework/test_runner.gd
class_name TestCase
extends RefCounted

const DEFAULT_EPSILON: float = 0.00001

var failures: PackedStringArray = []
## Number of engine errors (push_error / script errors) the current test intentionally triggers.
var expected_error_count: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func expect_errors(count: int) -> void:
	expected_error_count = count


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("expected false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected <%s> but got <%s>. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("expected value different from <%s>. %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, epsilon: float = DEFAULT_EPSILON,
		message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		fail("expected %.6f ± %.6f but got %.6f. %s" % [expected, epsilon, actual, message])


func assert_vec3_almost_eq(actual: Vector3, expected: Vector3, epsilon: float = DEFAULT_EPSILON,
		message: String = "") -> void:
	if actual.distance_to(expected) > epsilon:
		fail("expected %s ± %.6f but got %s. %s" % [str(expected), epsilon, str(actual), message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected non-null value. %s" % message)


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null but got <%s>. %s" % [str(value), message])
