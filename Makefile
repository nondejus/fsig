# A Self-Documenting Makefile: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

# Project variables
PACKAGE = $(shell echo $${PWD\#\#*src/})
BINARY_NAME = $(shell basename $$PWD)

# Build variables
BUILD_DIR = build
VERSION ?= $(shell git rev-parse --abbrev-ref HEAD)
COMMIT_HASH ?= $(shell git rev-parse --short HEAD 2>/dev/null)
BUILD_DATE ?= $(shell date +%FT%T%z)
LDFLAGS = -ldflags "-w -X main.Version=${VERSION} -X main.CommitHash=${COMMIT_HASH} -X main.BuildDate=${BUILD_DATE}"

# Dependency versions
DEP_VERSION = 0.5.0
GOLANGCI_VERSION = 1.10.2
GORELEASER_VERSION = 0.84.0

bin/dep: bin/dep-${DEP_VERSION}
bin/dep-${DEP_VERSION}:
	@mkdir -p bin
	@rm -rf bin/dep-*
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | INSTALL_DIRECTORY=./bin DEP_RELEASE_TAG=v${DEP_VERSION} sh
	@touch $@

.PHONY: vendor
vendor: bin/dep ## Install dependencies
	bin/dep ensure -vendor-only

.PHONY: clean
clean: ## Clean the working area and the project
	rm -rf bin/ ${BUILD_DIR}/ vendor/

.PHONY: build
build: ## Build a binary
	CGO_ENABLED=0 go build -tags '${TAGS}' ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME} ${PACKAGE}

.PHONY: check
check: test lint ## Run tests and linters

.PHONY: test
test: ## Run all tests
	go test -tags 'unit integration acceptance' ${ARGS} ./...

.PHONY: test-%
test-%: ## Run a specific test suite
	go test -tags '$*' ${ARGS} ./...

bin/golangci-lint: bin/golangci-lint-${GOLANGCI_VERSION}
bin/golangci-lint-${GOLANGCI_VERSION}:
	@mkdir -p bin
	@rm -rf bin/golangci-lint-*
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | bash -s -- -b ./bin/ v${GOLANGCI_VERSION}
	@touch $@

.PHONY: lint
lint: bin/golangci-lint ## Run linter
	bin/golangci-lint run

bin/goreleaser: bin/goreleaser-${GORELEASER_VERSION}
bin/goreleaser-${GORELEASER_VERSION}:
	@mkdir -p bin
	@rm -rf bin/goreleaser-*
	curl -sfL https://install.goreleaser.com/github.com/goreleaser/goreleaser.sh | bash -s -- v${GORELEASER_VERSION}
	@touch $@

.PHONY: release
release: bin/goreleaser ## Release current tag
	bin/goreleaser

release-%: ## Release a new version
	@sed -e "s/^## \[Unreleased\]$$/## [Unreleased]\\"$$'\n'"\\"$$'\n'"\\"$$'\n'"## [$*] - $$(date +%Y-%m-%d)/g" CHANGELOG.md > CHANGELOG.md.new
	@mv CHANGELOG.md.new CHANGELOG.md

	@sed -e "s|^\[Unreleased\]: \(.*\)HEAD$$|[Unreleased]: https://${PACKAGE}/compare/v$*...HEAD\\"$$'\n'"[$*]: \1v$*|g" CHANGELOG.md > CHANGELOG.md.new
	@mv CHANGELOG.md.new CHANGELOG.md

	@sed -e "s/ENV FSIG_VERSION .*/ENV FSIG_VERSION $*/g" README.md > README.md.new
	@mv README.md.new README.md

ifeq ($(TAG), true)
	git add CHANGELOG.md README.md
	git commit -s -S -m 'Prepare release v$*'
	git tag -s -m 'Release v$*' v$*
endif

	@echo "Version updated to $*!"
	@echo
	@echo "Review the changes made by this script then execute the following:"
ifneq ($(TAG), true)
	@echo
	@echo "git add CHANGELOG.md README.md && git commit -S -m 'Prepare release v$*' && git tag -s -m 'Release v$*' v$*"
	@echo
	@echo "Finally, push the changes:"
endif
	@echo
	@echo "git push; git push --tags"

.PHONY: patch
patch: ## Release a new patch version
	@$(MAKE) release-$(shell git describe --abbrev=0 --tags | sed 's/^v//' | awk -F'[ .]' '{print $$1"."$$2"."$$3+1}')

.PHONY: minor
minor: ## Release a new minor version
	@$(MAKE) release-$(shell git describe --abbrev=0 --tags | sed 's/^v//' | awk -F'[ .]' '{print $$1"."$$2+1".0"}')

.PHONY: major
major: ## Release a new major version
	@$(MAKE) release-$(shell git describe --abbrev=0 --tags | sed 's/^v//' | awk -F'[ .]' '{print $$1+1".0.0"}')

.PHONY: help
.DEFAULT_GOAL := help
help:
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Variable outputting/exporting rules
var-%: ; @echo $($*)
varexport-%: ; @echo $*=$($*)
