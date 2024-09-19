#!/bin/sh

set -e
set -x

# Define the publisher address
PUBLISHER_PROFILE=testnet-profile-1
PROFILE_OUTPUT=$(aptos config show-profiles --profile=$PUBLISHER_PROFILE)
PUBLISHER_ADDR=$(echo "$PROFILE_OUTPUT" | jq -r ".Result.\"$PUBLISHER_PROFILE\".account")

if [ -z "$PUBLISHER_ADDR" ]; then
  echo "Error: Publisher address not found."
  exit 1
fi

echo "Publisher Address: 0x$PUBLISHER_ADDR"

# Directory containing the Move source code
SOURCE_DIR="."

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist."
  exit 1
fi

# Check if the Move.toml file exists in the source directory
if [ ! -f "$SOURCE_DIR/Move.toml" ]; then
  echo "Error: Move.toml not found in $SOURCE_DIR."
  exit 1
fi

# Compile the module
echo "Compiling the module... $SOURCE_DIR"
aptos move compile --package-dir $SOURCE_DIR --named-addresses marketplace_addr=0x$PUBLISHER_ADDR,nft_addr=0x$PUBLISHER_ADDR --dev

# Publish the module to the testnet
echo "Publishing the module to the testnet..."
PUBLISH_OUTPUT=$(aptos move publish --package-dir $SOURCE_DIR --named-addresses marketplace_addr=0x$PUBLISHER_ADDR,nft_addr=0x$PUBLISHER_ADDR --profile $PUBLISHER_PROFILE --assume-yes)

# Extract the JSON part from the publish output
JSON_OUTPUT=$(echo "$PUBLISH_OUTPUT" | grep -o '{.*}')

# Extract the transaction hash from the JSON output
TRANSACTION_HASH=$(echo "$JSON_OUTPUT" | jq -r '.Result.transaction_hash')

if [ -z "$TRANSACTION_HASH" ]; then
  echo "Error: Failed to extract transaction hash from publish output."
  exit 1
fi

# Save the deployed address to marketplace.json
echo "{\"address\": \"$TRANSACTION_HASH\"}" > marketplace.json

echo "Module deployed successfully!"
echo "Deployed address saved to marketplace.json"