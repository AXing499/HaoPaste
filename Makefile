APP_NAME := HaoPaste
PROJECT := HaoPaste.xcodeproj
SCHEME := HaoPaste
CONFIG ?= Debug
DERIVED_DATA := .build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIG)/$(APP_NAME).app
DEMO_STORAGE := /tmp/haopaste-demo
RELEASE_DERIVED_DATA := .build/release
RELEASE_APP := $(RELEASE_DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app

.PHONY: project build run demo test release dmg install screenshots verify-screenshots clean

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) build -quiet

run: build
	open "$(APP_PATH)"

# Run the XCTest suite (hosted by the app, UI setup skipped in test mode).
test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA) test \
		-testLanguage en

# Launch with a throwaway history so the sample content is deterministic.
demo: build
	rm -rf "$(DEMO_STORAGE)"
	open -n "$(APP_PATH)" --args --demo --show --storage "$(DEMO_STORAGE)"

# Optimized app bundle for daily use. No Xcode needed to launch afterwards.
release: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(RELEASE_DERIVED_DATA) build -quiet

# Regenerate all Chinese and English README screenshots.
screenshots: project
	Scripts/generate-screenshots.sh

# Render screenshots and compare them with the committed baselines.
verify-screenshots: build
	Scripts/verify-screenshots.sh

# Build a double-clickable DMG in dist/ (app + Applications shortcut).
dmg: release
	Scripts/package-dmg.sh "$(RELEASE_APP)"

# Copy the Release app into /Applications (or ~/Applications) and launch it.
install: release
	Scripts/install-app.sh "$(RELEASE_APP)"

clean:
	rm -rf "$(DERIVED_DATA)" "$(RELEASE_DERIVED_DATA)" dist
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean -quiet || true
