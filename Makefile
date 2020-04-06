ifeq ($(OS),Windows_NT)
	BUNDLE = bundle.exe
	YARDOC = ../yard/bin/yardoc.bat
else
	BUNDLE = bundle
	YARDOC = ../yard/bin/yardoc
endif

.PHONY: default test-dep test dep

default: dep

test-dep:
	cd testdata/case/ruby-sample-0 && $(BUNDLE) install
	cd testdata/case/ruby_sample_xref_app && $(BUNDLE) install
	cd testdata/case/sample_ruby_gem && $(BUNDLE) install
	cd testdata/case/rails-sample && $(BUNDLE) install

test:
	src -v test -m program

test-gen-program:
	src test -m program --gen

dep:
	$(BUNDLE) install
	cd yard && $(BUNDLE) install
