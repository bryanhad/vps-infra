# `make up` builds and starts the stack. It first asks git for the backend's
# version, because the app's Docker build cannot see .git.
RALLY_POINT_DIR ?= ../rally-point
SERVICE ?=

.PHONY: up
up:
	BACKEND_VERSION=$$($(RALLY_POINT_DIR)/scripts/version.sh) \
	RALLY_POINT_DIR=$(RALLY_POINT_DIR) \
	docker compose up -d --build $(SERVICE)
