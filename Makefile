.PHONY: build bundle install clean

build:
	swift build -c release

bundle: build
	bash scripts/bundle.sh

install: bundle
	cp -R TendiesApp.app /Applications/
	@echo "Installed to /Applications/TendiesApp.app"

clean:
	rm -rf .build TendiesApp.app
