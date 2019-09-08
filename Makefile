.PHONY: docs clean-docs

docs:
	perl6 -Ilib tools/make-docs.pl6

clean-docs:
	rm -rf docs/Red.pm6 API.pm6
	rm -rf docs/api
