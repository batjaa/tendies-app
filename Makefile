.PHONY: dev build bundle install clean

dev:
	swift build
	@mkdir -p TendiesApp.app/Contents/MacOS
	cp .build/debug/TendiesApp TendiesApp.app/Contents/MacOS/TendiesApp
	@echo "Updated TendiesApp.app with debug build"

build:
	swift build -c release

bundle: build
	bash scripts/bundle.sh

install: bundle
	cp -R TendiesApp.app /Applications/
	@echo "Installed to /Applications/TendiesApp.app"

clean:
	rm -rf .build TendiesApp.app
