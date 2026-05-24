extends TestCase

const GeneratorScript := preload("res://scripts/username_generator.gd")

func test_generated_names_have_expected_shape() -> void:
	# Manually instance the script since the autoload is not present in headless
	# test runs.
	var generator := Node.new()
	generator.set_script(GeneratorScript)
	for _i in range(20):
		var name: String = generator.generate()
		assert_true(name.length() >= 5, "name should be non-trivial")
		assert_true(name == name.strip_edges(), "name should not have surrounding whitespace")
		var last_three := name.substr(name.length() - 3, 3)
		assert_true(last_three.is_valid_int(), "last three chars should be digits: %s" % name)
	generator.free()
