.PHONY: docs clean-docs

docs:
	perl6 -Ilib tools/make-docs.raku

clean-docs:
	rm -rf docs/Red.rakumod API.rakumod
	rm -rf docs/api
