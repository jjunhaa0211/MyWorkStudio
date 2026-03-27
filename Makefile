SHELL := /bin/zsh

MISE := mise exec --
TUIST := $(MISE) tuist
DERIVED_DATA := $(CURDIR)/build/DofficeDerivedData
APP_PATH := $(DERIVED_DATA)/Build/Products/Debug/Doffice.app

.PHONY: dofi clean-tuist generate build-app open-app

dofi: clean-tuist generate build-app open-app

clean-tuist:
	@echo "==> Cleaning Tuist artifacts"
	@$(TUIST) clean
	@rm -rf "$(DERIVED_DATA)"

generate:
	@echo "==> Generating project with Tuist $$( $(TUIST) version )"
	@$(TUIST) generate

build-app:
	@echo "==> Building Doffice"
	@xcodebuild build \
		-workspace Doffice.xcworkspace \
		-scheme Doffice \
		-destination 'platform=macOS' \
		-derivedDataPath "$(DERIVED_DATA)"

open-app:
	@echo "==> Opening built app"
	@open -n "$(APP_PATH)"
	@for _ in {1..20}; do \
		if pgrep -x Doffice >/dev/null; then \
			echo "==> Doffice is running"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Doffice did not start as expected" >&2; \
	exit 1
