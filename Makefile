# Makefile for C project with OpenSSL support on Mac M4 (Apple Silicon)

# Project configuration
PROJECT_NAME = your_project
SRC_DIR = src
BUILD_DIR = build
LIBS_DIR = libs
INCLUDE_DIR = $(LIBS_DIR)/include

# Compiler and flags
CC = gcc
CFLAGS = -std=c99 -Wall -Wextra -O2 -g

# OpenSSL configuration for Mac M4 (Apple Silicon)
# Automatically detect if we're on Apple Silicon and set OpenSSL paths
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
    # Mac M4/Apple Silicon - use Homebrew paths
    OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null)
    ifneq ($(OPENSSL_PREFIX),)
        CFLAGS += -I$(OPENSSL_PREFIX)/include
        LDFLAGS += -L$(OPENSSL_PREFIX)/lib
        PKG_CONFIG_PATH := $(OPENSSL_PREFIX)/lib/pkgconfig
    else
        $(warning OpenSSL@3 not found via Homebrew. Please install with: brew install openssl@3)
    endif
else
    # Intel Mac or other systems - try standard paths
    OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null || echo /usr/local/opt/openssl@3)
    ifneq ($(wildcard $(OPENSSL_PREFIX)/include),)
        CFLAGS += -I$(OPENSSL_PREFIX)/include
        LDFLAGS += -L$(OPENSSL_PREFIX)/lib
        PKG_CONFIG_PATH := $(OPENSSL_PREFIX)/lib/pkgconfig
    endif
endif

# Include directories (for headers)
CFLAGS += -I$(INCLUDE_DIR)

# Add local library directory to linker search path
LDFLAGS += -L$(LIBS_DIR)

# Libraries to link - including local static libraries
LIBS = -lssl -lcrypto -lcjose $(LIBS_DIR)/miracl-core/c/core.a

# Also need jansson for CJOSE (add if available via Homebrew)
ifeq ($(UNAME_M),arm64)
    JANSSON_PREFIX := $(shell brew --prefix jansson 2>/dev/null)
    ifneq ($(JANSSON_PREFIX),)
        LDFLAGS += -L$(JANSSON_PREFIX)/lib
        LIBS += -ljansson
    endif
else
    JANSSON_PREFIX := $(shell brew --prefix jansson 2>/dev/null || echo /usr/local/opt/jansson)
    ifneq ($(wildcard $(JANSSON_PREFIX)/lib),)
        LDFLAGS += -L$(JANSSON_PREFIX)/lib
        LIBS += -ljansson
    endif
endif

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)

# Main target
TARGET = $(BUILD_DIR)/$(PROJECT_NAME)

# Default target
.PHONY: all
all: $(TARGET)

# Build required local libraries first
.PHONY: build-libs
build-libs:
	@echo "Checking for required libraries..."
	@if [ ! -f "$(LIBS_DIR)/libcjose.a" ] || [ ! -f "$(LIBS_DIR)/miracl-core/c/core.a" ]; then \
		echo "Building required libraries..."; \
		./build.sh; \
	else \
		echo "✓ Required libraries already built"; \
	fi

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile object files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Link the final executable (depends on libraries being built)
$(TARGET): build-libs $(OBJECTS)
	@echo "Linking $(TARGET)..."
	$(CC) $(OBJECTS) $(LDFLAGS) $(LIBS) -o $(TARGET)

# Force rebuild of libraries
.PHONY: rebuild-libs
rebuild-libs:
	@echo "Force rebuilding libraries..."
	./build.sh

# Debug target to show configuration
.PHONY: debug-config
debug-config:
	@echo "=== Build Configuration ==="
	@echo "Architecture: $(UNAME_M)"
	@echo "OpenSSL Prefix: $(OPENSSL_PREFIX)"
	@echo "Jansson Prefix: $(JANSSON_PREFIX)"
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "LDFLAGS: $(LDFLAGS)"
	@echo "LIBS: $(LIBS)"
	@echo "PKG_CONFIG_PATH: $(PKG_CONFIG_PATH)"
	@echo "Sources: $(SOURCES)"
	@echo "Objects: $(OBJECTS)"
	@echo "Target: $(TARGET)"
	@echo ""
	@echo "=== Library Status ==="
	@if [ -f "$(LIBS_DIR)/libcjose.a" ]; then \
		echo "✓ CJOSE library found: $(LIBS_DIR)/libcjose.a"; \
	else \
		echo "✗ CJOSE library missing: $(LIBS_DIR)/libcjose.a"; \
	fi
	@if [ -f "$(LIBS_DIR)/miracl-core/c/core.a" ]; then \
		echo "✓ MIRACL Core library found: $(LIBS_DIR)/miracl-core/c/core.a"; \
	else \
		echo "✗ MIRACL Core library missing: $(LIBS_DIR)/miracl-core/c/core.a"; \
	fi

# Test OpenSSL detection
.PHONY: test-openssl
test-openssl:
	@echo "Testing OpenSSL detection..."
	@if [ -d "$(OPENSSL_PREFIX)/include/openssl" ]; then \
		echo "✓ OpenSSL headers found at $(OPENSSL_PREFIX)/include/openssl"; \
		ls $(OPENSSL_PREFIX)/include/openssl/ | head -5; \
	else \
		echo "✗ OpenSSL headers not found at $(OPENSSL_PREFIX)/include/openssl"; \
		echo "Please install OpenSSL with: brew install openssl@3"; \
	fi
	@if [ -d "$(OPENSSL_PREFIX)/lib" ]; then \
		echo "✓ OpenSSL libraries found at $(OPENSSL_PREFIX)/lib"; \
		ls $(OPENSSL_PREFIX)/lib/libssl* $(OPENSSL_PREFIX)/lib/libcrypto* 2>/dev/null || echo "No SSL libraries found"; \
	else \
		echo "✗ OpenSSL libraries not found at $(OPENSSL_PREFIX)/lib"; \
	fi

# Install dependencies (OpenSSL and Jansson)
.PHONY: install-deps
install-deps:
	@echo "Installing dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing OpenSSL and Jansson via Homebrew..."; \
		brew install openssl@3 jansson; \
	else \
		echo "Homebrew not found. Please install Homebrew first."; \
		exit 1; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

# Clean everything including built libraries
.PHONY: clean-all
clean-all: clean
	@echo "Cleaning all built libraries..."
	rm -f $(LIBS_DIR)/libcjose.a
	rm -f $(LIBS_DIR)/miracl-core/c/core.a
	@echo "Run 'make rebuild-libs' to rebuild libraries"

# Force rebuild
.PHONY: rebuild
rebuild: clean all

# Run the program
.PHONY: run
run: $(TARGET)
	$(TARGET)

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all           - Build the project (default)"
	@echo "  build-libs    - Build local libraries (CJOSE and MIRACL Core)"
	@echo "  rebuild-libs  - Force rebuild of local libraries"
	@echo "  clean         - Remove build artifacts"
	@echo "  clean-all     - Remove build artifacts and built libraries"
	@echo "  rebuild       - Clean and build"
	@echo "  run           - Build and run the program"
	@echo "  debug-config  - Show build configuration and library status"
	@echo "  test-openssl  - Test OpenSSL detection"
	@echo "  install-deps  - Install dependencies via Homebrew"
	@echo "  help          - Show this help"

# Export PKG_CONFIG_PATH for child processes
export PKG_CONFIG_PATH