APP_NAME := HaoPaste
PROJECT := HaoPaste.xcodeproj
SCHEME := HaoPaste
CONFIG ?= Debug
DERIVED_DATA := .build
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIG)/$(APP_NAME).app
DEMO_STORAGE := /tmp/haopaste-demo

.PHONY: project build run demo clean

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) build -quiet

run: build
	open "$(APP_PATH)"

# Launch with a throwaway history so the sample content is deterministic.
demo: build
	rm -rf "$(DEMO_STORAGE)"
	open -n "$(APP_PATH)" --args --demo --show --storage "$(DEMO_STORAGE)"

clean:
	rm -rf "$(DERIVED_DATA)"
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean -quiet || true
