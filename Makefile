.PHONY: dev watch build bundle install clean icon

dev: icon
	swift build
	@mkdir -p TendiesApp.app/Contents/MacOS
	@mkdir -p TendiesApp.app/Contents/Resources
	cp .build/debug/TendiesApp TendiesApp.app/Contents/MacOS/TendiesApp
	cp Resources/Info.plist TendiesApp.app/Contents/Info.plist
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns TendiesApp.app/Contents/Resources/AppIcon.icns; \
	fi
	@echo "Updated TendiesApp.app with debug build (including Info.plist and icon if available)"

icon:
	@bash scripts/build-app-icon.sh || echo "Warning: failed to build AppIcon.icns; continuing without custom icon"

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
