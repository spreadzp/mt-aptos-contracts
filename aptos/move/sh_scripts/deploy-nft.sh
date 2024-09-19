#!/bin/sh

set -e
set -x

echo "##### Deploy NFT module #####"

# Profile is the account you used to execute the transactions
PUBLISHER_PROFILE=testnet-profile-1
echo "Publisher Profile: $PUBLISHER_PROFILE"

# Extract the publisher address from the profile configuration
PROFILE_OUTPUT=$(aptos config show-profiles --profile=$PUBLISHER_PROFILE)
echo "Profile Output: $PROFILE_OUTPUT"

# Use jq to extract the account address
PUBLISHER_ADDR=$(echo "$PROFILE_OUTPUT" | jq -r ".Result.\"$PUBLISHER_PROFILE\".account")

echo "Publisher Address: 0x$PUBLISHER_ADDR"

# Directory containing the Move source code
SOURCE_DIR="./sources"
BUILD_DIR="./build"

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist."
  exit 1
fi

# Ensure the build directory exists
if [ ! -d "$BUILD_DIR" ]; then
  echo "Creating build directory $BUILD_DIR"
  mkdir -p $BUILD_DIR
fi

cd $BUILD_DIR

# Deploy NFT module
DEPLOY_NFT_COMMAND="aptos move create-object-and-publish-package --address-name nft_addr --named-addresses nft_addr=$PUBLISHER_ADDR,marketplace_addr=$PUBLISHER_ADDR --profile $PUBLISHER_PROFILE --assume-yes"
echo "Executing command: $DEPLOY_NFT_COMMAND"

# Execute the deployment command and log output
OUTPUT_NFT=$(eval $DEPLOY_NFT_COMMAND | tee deploy_nft.log)

# Sleep to allow time for deployment to process
sleep 10

# Extract NFT contract address from the output
CONTRACT_ADDRESS_NFT=$(echo "$OUTPUT_NFT" | grep "Code was successfully deployed to object address" | awk '{print $NF}' | sed 's/\.$//')
echo "NFT contract deployed to address: $CONTRACT_ADDRESS_NFT"

if [ -z "$CONTRACT_ADDRESS_NFT" ]; then
  echo "Error: NFT contract deployment failed."
  exit 1
fi

echo "$CONTRACT_ADDRESS_NFT" > contract_address_nft.txt
echo "NFT contract address saved to contract_address_nft.txt"
