#!/bin/bash

# Build script for CJOSE and MIRACL Core libraries
# This script builds both libraries as static libraries for integration

set -e

PROJECT_ROOT="$(pwd)"

echo "Building CJOSE and MIRACL Core libraries..."
echo "Project root: ${PROJECT_ROOT}"

# Build MIRACL Core first (since it's simpler)
echo
echo "=== Building MIRACL Core ==="
cd libs/miracl-core/c

# Build MIRACL Core with NIST256 curve
echo "Configuring MIRACL Core with NIST256..."
python3 config64.py -o 3  # Option 3 is NIST256

if [ ! -f "core.a" ]; then
    echo "Error: MIRACL Core library (core.a) was not created"
    exit 1
fi

echo "MIRACL Core built successfully: core.a"

# Copy MIRACL headers to common include directory
echo "Copying MIRACL headers..."
cd "${PROJECT_ROOT}"
cp libs/miracl-core/c/core.h libs/include/
cp libs/miracl-core/c/big_256_56.h libs/include/
cp libs/miracl-core/c/fp_NIST256.h libs/include/
cp libs/miracl-core/c/ecp_NIST256.h libs/include/
cp libs/miracl-core/c/ecdh_NIST256.h libs/include/
cp libs/miracl-core/c/eddsa_NIST256.h libs/include/
cp libs/miracl-core/c/hpke_NIST256.h libs/include/
cp libs/miracl-core/c/config_big_256_56.h libs/include/
cp libs/miracl-core/c/config_field_NIST256.h libs/include/
cp libs/miracl-core/c/config_curve_NIST256.h libs/include/
cp libs/miracl-core/c/arch.h libs/include/

echo "MIRACL headers copied to libs/include/"

# Build CJOSE
echo
echo "=== Building CJOSE ==="
cd libs/cjose

# Check if we need to run autoreconf
if [ ! -f "configure" ]; then
    echo "Running autoreconf to generate configure script..."
    autoreconf --force --install
fi

# Configure CJOSE
echo "Configuring CJOSE..."

# Set up configure options
CONFIGURE_OPTS="--disable-shared --enable-static"

# Try to detect OpenSSL and Jansson locations
if pkg-config --exists openssl; then
    OPENSSL_CFLAGS="$(pkg-config --cflags openssl)"
    OPENSSL_LIBS="$(pkg-config --libs openssl)"
    export CPPFLAGS="${CPPFLAGS} ${OPENSSL_CFLAGS}"
    export LDFLAGS="${LDFLAGS} ${OPENSSL_LIBS}"
fi

if pkg-config --exists jansson; then
    JANSSON_CFLAGS="$(pkg-config --cflags jansson)"
    JANSSON_LIBS="$(pkg-config --libs jansson)"
    export CPPFLAGS="${CPPFLAGS} ${JANSSON_CFLAGS}"
    export LDFLAGS="${LDFLAGS} ${JANSSON_LIBS}"
fi

# Handle macOS OpenSSL location (if using Homebrew)
if [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
    if brew list openssl &>/dev/null; then
        OPENSSL_ROOT="$(brew --prefix openssl)"
        CONFIGURE_OPTS="${CONFIGURE_OPTS} --with-openssl=${OPENSSL_ROOT}"
    fi

    if brew list jansson &>/dev/null; then
        JANSSON_ROOT="$(brew --prefix jansson)"
        CONFIGURE_OPTS="${CONFIGURE_OPTS} --with-jansson=${JANSSON_ROOT}"
    fi
fi

echo "Configure options: ${CONFIGURE_OPTS}"

./configure ${CONFIGURE_OPTS}

# Build CJOSE
echo "Building CJOSE..."
make clean || true  # Clean any previous builds (ignore errors)
make

if [ ! -f "src/.libs/libcjose.a" ]; then
    echo "Error: CJOSE static library was not created"
    echo "Checking for alternative locations..."
    find . -name "libcjose.a" -type f
    exit 1
fi

# Copy CJOSE library and headers
echo "Copying CJOSE library and headers..."
cd "${PROJECT_ROOT}"

# Copy the static library
cp libs/cjose/src/.libs/libcjose.a libs/

# Copy headers
mkdir -p libs/include/cjose
cp libs/cjose/include/cjose/*.h libs/include/cjose/

echo "CJOSE built successfully: libcjose.a"

# Create a summary
echo
echo "=== Build Summary ==="
echo "Libraries built:"
echo "  - MIRACL Core: libs/miracl-core/c/core.a"
echo "  - CJOSE: libs/libcjose.a"
echo
echo "Headers copied to: libs/include/"
echo "  - MIRACL Core headers: core.h, big_256_56.h, fp_NIST256.h, etc."
echo "  - CJOSE headers: cjose/*.h"
echo
echo "Build completed successfully!"
echo
echo "You can now:"
echo "1. Include headers: #include \"core.h\" and #include \"cjose/cjose.h\""
echo "2. Link libraries: -L./libs -lcjose ./libs/miracl-core/c/core.a"
echo "3. Add system dependencies: -lssl -lcrypto -ljansson"