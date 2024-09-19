## Env setup

Check out the guide from [Aptos Learn](https://learn.aptoslabs.com/example/aptogotchi-beginner/env-setup).

## Play with testnet deployments on explorer

Go to testnet explorer [here](https://explorer.aptoslabs.com/?network=testnet) and search for the contract address.

You can find the contract address in each contract directory's `contract_address.txt`.

On explorer, you can read the contract code, call entry functions (need to connect wallet), and call view functions.

## Development

In each contract's `move` directory, you can run below commands.

Run unit test
# Initialize the Aptos CLI and create a profile
aptos init --profile testnet-profile-1

# Verify the profile configuration
aptos config show-profiles --profile testnet-profile-1

```sh
aptos move run --function-id 'default::message::set_message' --args 'string:Hello Chainstack dev'


 


aptos node run-local-testnet --with-faucet
aptos node run-local-testnet --with-faucet --p http://localhost:8090 
aptos init --profile local --rest-url http://localhost:8080 --faucet-url http://localhost:8081
local
if need restart  aptos node run-local-testnet --with-faucet --force-restart
aptos account fund-with-faucet --profile $PROFILE --account $PROFILE
aptos account fund-with-faucet  --account 0xf6b79100da387d0a15f47a70882f5b7128daf148b3fdcbb5473bbd24f2358a0f
 aptos account fund-with-faucet --profile local --account local
 aptos account list --query resources --account default --profile $PROFILE # or just "account list"
 aptos account list --query resources --account default --profile local
 aptos account list --query modules --profile $PROFILE
 aptos account list --query modules --profile local

 aptos init --profile bob --rest-url http://localhost:8080 --faucet-url http://localhost:8081
 aptos account transfer --account bob --amount 100 --profile local
 aptos move compile --package-dir [path-to-example]/hello_blockchain --named-addresses hello_blockchain=$PROFILE --profile $PROFILEnt transfer --account 0x2df41622c0c1baabaa73b2c24360d205e23e803959ebbcb0e5b80462165893ed --amount 100 --profile testnet9
 aptos move publish --package-dir move --named-addresses marketplace_addr=local --profile local
 aptos move run --function-id 4a327db3bce440f47d65b293a9688a7fd59e69a3cc1ddf0b2889a3e4f6d4de62::message::set_message --args string:Hello! --profile $PROFILE
aptos key generate --key-type ed25519 --output-file output.key
https://noncegeek.medium.com/aptos-cli-usage-guide-and-repl-design-suggestions-learning-move-0x04-b22720b99e98
 https://explorer.aptoslabs.com/txn/0x9d57d84903fc6d4c54ac5a10271647c3c10bc5228a5e94c55618f2c6b1180779?network=local


aptos move compile --package-dir move/sources/marketplace.move --dev
aptos move compile --package-dir move --dev
./sh_scripts/test.sh
```

Deploy to testnet
aptos move publish --package-dir move/sources --profile testnet-profile-1 --assume-yes
aptos move publish --package-dir move/sources --named-addresses marketplace_addr=0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6,nft_addr=0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --profile testnet-profile-1 --assume-yes
aptos move upgrade-object-package --object-address 0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --named-addresses marketplace_addr=0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --dev --url 

aptos move publish --package-dir sources --profile testnet-profile-1 --assume-yes


in folder move 
aptos move create-object-and-publish-package --address-name marketplace_addr --profile default --assume-yes marketplace_addr=0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --profile default --assume-yes
aptos move upgrade-object-package --object-address 0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --named-addresses marketplace_addr=0xd348822abc4c50a68be8be6382f1883deeb365bf54367791ab9ed584f67b9cc6 --profile default --assume-yes

// in move folder
aptos move create-object-and-publish-package --address-name marketplace_addr,nft_addr --profile default --assume-yes
aptos move upgrade-object-package  --object-address 0xe3995d3baea60c08ea0ee2637e1031f4ca4c2a9b50cb79e70f1f8b981c912639  --profile default --assume-yes

https://explorer.aptoslabs.com/txn/0x226ded1328a30f685955a090ece0126b6de3bac8f2199c6713e41301984aa0c9?network=testnet
deployed to object address 0x0b906b870d8bbbc8d9ca455d8518886453e00b2d76b39449b0edf23053023b7c

aptos move create-object-and-publish-package \
  --address-name aptogotchi_addr \
  --named-addresses aptogotchi_addr=$PUBLISHER_ADDR\
  --profile $PUBLISHER_PROFILE \
	--assume-yes



```sh
./sh_scripts/deploy.sh
```

Upgrade deployed contract

```sh
./sh_scripts/upgrade.sh
```

Run Move scripts. Move scripts are off-chain Move functions that let you call multiple functions atomically 

```sh
# You can explorer what other scripts are available in sh_scripts
./sh_scripts/create_and_mint_some_fas.sh


in move folder 
aptos move create-object-and-publish-package --address-name marketplace_addr --profile default --assume-yes 
aptos move publish --package-dir move/sources --profile default --assume-yes
aptos move publish --package-dir move/sources --profile default --dev
aptos move publish --package-dir sources --named-addresses marketplace_addr=0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a,nft_addr=0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a --profile default --assume-yes
aptos move upgrade-object-package  --object-address 0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a  --profile default --assume-yes
```
0xfc85aa988050c0bb1abb7e84171d16674d6e5c69b1687f00c9ce078615df9f4a
https://explorer.aptoslabs.com/txn/0x25a51d28634b5d1974f3f44f260d25d46b26498bbac711b56ff58650520582a4?network=testnet

https://aptoscan.com/module/0xd80f67b134fa1bead50678184c4550a59f90349ed004184f995916cd1dd93a97/marketplace?network=testnet  => ABI


https://explorer.aptoslabs.com/txn/0x09e4a13cf1cf12b5a7b5337146eb8c2df8812871ed7ab43e430dde941cf8dfe5?network=testnet
0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a


https://aptoscan.com/module/0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a/marketplace?network=testnet
https://aptoscan.com/module/0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a/nft?network=testnet

0x8ac0bf0166af96c7e79dcd6c879cd2a14290b78c6c0f1c060ce66152c4001d9a::nft::NFT

