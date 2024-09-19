#!/bin/sh

set -e

# Directory containing the Move source code
SOURCE_DIR="./sources"

# Read the contract address from the file
CONTRACT_ADDRESS=$(cat "./contract_address.txt")

# Function to compile the source code
compile_source_code() {
  echo "Compiling source code..."
  aptos move compile --named-addresses marketplace_addr=$CONTRACT_ADDRESS --package-dir $SOURCE_DIR 2>&1
}

# Attempt to compile the source code
OUTPUT=$(compile_source_code)

# Check if the compilation was successful
if [ $? -ne 0 ]; then
  echo "Error during compilation:"
  echo "$OUTPUT"
  exit 1
fi

# Check if the build directory exists
BUILD_DIR="./build"
echo "Build directory: $BUILD_DIR"
if [ ! -d "$BUILD_DIR" ]; then
  echo "Error: Build directory not found at $BUILD_DIR."
  echo "Compilation output:"
  echo "$OUTPUT"
  exit 1
fi

# Navigate to the build directory
cd $BUILD_DIR
echo "Current working directory: $(pwd)"
echo "Build directory contents: $(ls)"

# Find the ABI.json file
ABI_FILE=$(find . -name "ABI.json" | head -n 1)

# Check if the ABI file was found
if [ -z "$ABI_FILE" ]; then
  echo "Error: ABI.json file not found in the build directory."
  echo "Build directory contents:"
  ls -R $BUILD_DIR
  exit 1
fi

# Copy the ABI file to the current directory
cp $ABI_FILE ./ABI.json

echo "ABI.json file extracted and saved to the current directory."