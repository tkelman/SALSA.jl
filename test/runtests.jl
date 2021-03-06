tests = ["unit/test_pegasos", 
		 "unit/test_wrapper", 
		 "functional/regression/test_fsinc",
		 # "functional/clustering/test_clustering",
		 "functional/classification/test_linear",
		 "functional/classification/test_multiclass",
		 "functional/classification/test_nonlinear",
		 "functional/test_wrapper"]

print_with_color(:blue, "Running tests:\n")

for t in tests
	test_fn = "$t.jl"
	print_with_color(:green, "* $test_fn\n")
	include(test_fn)
end