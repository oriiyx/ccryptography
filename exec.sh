#!/bin/bash

# Project Setup Script for CJOSE + MIRACL Core Integration
# This script creates the complete project structure and downloads/builds both libraries

set -e  # Exit on any error

PROJECT_NAME="crypto_project"
PROJECT_ROOT="$(pwd)/${PROJECT_NAME}"

echo "Creating project structure..."

# Create main project directories
mkdir -p "${PROJECT_ROOT}"
cd "${PROJECT_ROOT}"

mkdir -p libs/{cjose,miracl-core,include}
mkdir -p src
mkdir -p build
mkdir -p docs

echo "Project structure created at: ${PROJECT_ROOT}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "Checking dependencies..."

MISSING_DEPS=()

if ! command_exists git; then
    MISSING_DEPS+=("git")
fi

if ! command_exists python3; then
    MISSING_DEPS+=("python3")
fi

if ! command_exists gcc; then
    MISSING_DEPS+=("gcc")
fi

if ! command_exists make; then
    MISSING_DEPS+=("make")
fi

if ! command_exists autoconf; then
    MISSING_DEPS+=("autoconf")
fi

if ! command_exists automake; then
    MISSING_DEPS+=("automake")
fi

if ! command_exists libtool; then
    MISSING_DEPS+=("libtool")
fi

if ! command_exists pkg-config; then
    MISSING_DEPS+=("pkg-config")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Please install them first:"
    echo "  Ubuntu/Debian: sudo apt-get install ${MISSING_DEPS[*]}"
    echo "  CentOS/RHEL: sudo yum install ${MISSING_DEPS[*]}"
    echo "  macOS: brew install ${MISSING_DEPS[*]}"
    exit 1
fi

# Check for OpenSSL and Jansson
echo "Checking for OpenSSL and Jansson..."

if ! pkg-config --exists openssl; then
    echo "Warning: OpenSSL development headers not found"
    echo "Install with: sudo apt-get install libssl-dev (Ubuntu) or brew install openssl (macOS)"
fi

if ! pkg-config --exists jansson; then
    echo "Warning: Jansson development headers not found"
    echo "Install with: sudo apt-get install libjansson-dev (Ubuntu) or brew install jansson (macOS)"
fi

echo "Downloading libraries..."

# Download CJOSE
cd libs/cjose
echo "Cloning CJOSE library..."
git clone https://github.com/OpenIDC/cjose.git .
echo "CJOSE downloaded successfully"

# Download MIRACL Core
cd ../miracl-core
echo "Cloning MIRACL Core library..."
git clone https://github.com/miracl/core.git .
echo "MIRACL Core downloaded successfully"

cd "${PROJECT_ROOT}"
echo "All libraries downloaded successfully!"
echo
echo "Next steps:"
echo "1. cd ${PROJECT_ROOT}"
echo "2. Run the build script: ./build_libs.sh"
echo "3. Start developing in the src/ directory"