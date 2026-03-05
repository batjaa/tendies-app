.PHONY: dev watch build bundle install clean

dev:
	swift build
	@mkdir -p TendiesApp.app/Contents/MacOS
	cp .build/debug/TendiesApp TendiesApp.app/Contents/MacOS/TendiesApp
	@echo "Updated TendiesApp.app with debug build"

watch:
	@echo "Watching Sources/ for changes..."
	@$(MAKE) dev
	@fswatch -o -l 0.5 Sources/ | while read _; do \
		echo "\n--- Rebuilding... ---"; \
		pkill -x TendiesApp 2>/dev/null || true; \
		$(MAKE) dev && open TendiesApp.app; \
	done

build:
	swift build -c release

bundle: build
	bash scripts/bundle.sh

install: bundle
	cp -R TendiesApp.app /Applications/
	@echo "Installed to /Applications/TendiesApp.app"

clean:
	rm -rf .build TendiesApp.app
