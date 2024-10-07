#[test_only]
module marketplace_addr::test_utils {
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use aptos_framework::object;
    use aptos_token_objects::token;
    use aptos_token_objects::aptos_token;
    use aptos_token_objects::collection;
    use marketplace_addr::marketplace;

    public inline fun setup(
        aptos_framework: &signer,
        marketplace: &signer,
        seller: &signer,
        purchaser: &signer
    ): (address, address, address) {
        marketplace::setup_test(marketplace);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let marketplace_addr = signer::address_of(marketplace);
        account::create_account_for_test(marketplace_addr);
        coin::register<aptos_coin::AptosCoin>(marketplace);

        let seller_addr = signer::address_of(seller);
        account::create_account_for_test(seller_addr);
        coin::register<aptos_coin::AptosCoin>(seller);

        let purchaser_addr = signer::address_of(purchaser);
        account::create_account_for_test(purchaser_addr);
        coin::register<aptos_coin::AptosCoin>(purchaser);

        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(seller_addr, coins);
        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(purchaser_addr, coins);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
        // debug::print(&string::utf8(b"Listing NFT for sale at a fixed price"));
        // debug::print(&string::utf8(b"NFT listed for sale"));

        (marketplace_addr, seller_addr, purchaser_addr)
    }

    public fun mint_tokenv2_with_collection(
        seller: &signer
    ): (object::Object<collection::Collection>, object::Object<token::Token>) {
        let collection_name = string::utf8(b"collection_name");

        let collection_object =
            aptos_token::create_collection_object(
                seller,
                string::utf8(b"collection description"),
                2,
                collection_name,
                string::utf8(b"collection uri"),
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                true,
                1,
                100
            );

        let aptos_token =
            aptos_token::mint_token_object(
                seller,
                collection_name,
                string::utf8(b"description"),
                string::utf8(b"token_name"),
                string::utf8(b"uri"),
                vector::empty(),
                vector::empty(),
                vector::empty()
            );
        (object::convert(collection_object), object::convert(aptos_token))
    }

    public fun mint_tokenv2(seller: &signer): object::Object<token::Token> {
        let (_collection, token) = mint_tokenv2_with_collection(seller);
        token
    }
}

// Test changing the listing price of an NFT
// #[test(creator = @0x1, marketplace = @marketplace_addr)]
// public entry fun test_change_listing_price(creator: &signer, marketplace: &signer) {
//     account::create_account_for_test(signer::address_of(creator));
//     marketplace::setup_test(marketplace);

//     let metadata = string::utf8(b"https://example.com/nft8");
//     let token_id = nft::test_initialize_nft(creator, metadata);

//     let initial_price = 1000;
//     marketplace::list_nft_with_fixed_price(creator, token_id, initial_price);

//     let new_price = 1500;
//     let listing_id = marketplace::get_nft_listing(token_id);
//     assert!(listing_id != @0x0, 0); // Ensure the listing ID is not zero

//     let seller_listings = marketplace::get_seller_listings(signer::address_of(creator));
//     let listing_address = *vector::borrow(&seller_listings, 0);
//     let listing_object = object::address_to_object<marketplace::ListingWithPrice>(listing_address);
//     marketplace::change_listing_price(creator, listing_object, new_price);

//     let (object, seller, listed_price) = marketplace::listing(listing_object);
//     assert!(listed_price == new_price, 1);
// }

// Test claiming an NFT by ID
// #[test(creator = @0x1, marketplace = @marketplace_addr)]
// public entry fun test_claim_nft_by_id(creator: &signer, marketplace: &signer) {
//     account::create_account_for_test(signer::address_of(creator));
//     marketplace::setup_test(marketplace);

//     let metadata = string::utf8(b"https://example.com/nft9");
//     let token_id = nft::test_initialize_nft(creator, metadata);

//     let price = 1000;
//     marketplace::list_nft_with_fixed_price(creator, token_id, price);

//     let seller_listings = marketplace::get_seller_listings(signer::address_of(creator));
//     let listing_address = *vector::borrow(&seller_listings, 0);

//     marketplace::claim_nft_by_id(creator, listing_address); // Use listing address

//     // Verify the listing is removed
//     assert!(!marketplace::exists_listing(listing_address), 1); // Use listing address
// }

// #[test(creator = @0x1, buyer = @0x2, marketplace = @marketplace_addr, aptos_framework = @aptos_framework)]
// public entry fun test_accept_bid(
//     creator: &signer,
//     buyer: &signer,
//     marketplace: &signer,
//     aptos_framework: &signer
// ) {
//     // Initialize the Aptos coin
//     let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

//     account::create_account_for_test(signer::address_of(creator));
//     account::create_account_for_test(signer::address_of(buyer));
//     marketplace::setup_test(marketplace);

//     let metadata = string::utf8(b"https://example.com/nft8");
//     let token_id = nft::test_initialize_nft(creator, metadata);
//     debug::print(&string::utf8(b"token_id:"));
//     debug::print(&token_id);

//     let list_price = 1000;
//     marketplace::list_nft_with_fixed_price(creator, token_id, list_price);

//     let listing_addr = marketplace::get_nft_listing(token_id);
//     debug::print(&string::utf8(b"test_accept_bid => get_nft_listing:"));
//     debug::print(&listing_addr);

//     let bid_price = 1200; // Higher than the list price

//     // Fund buyer's account with AptosCoin
//     coin::register<AptosCoin>(buyer);
//     let buyer_addr = signer::address_of(buyer);
//     coin::deposit<AptosCoin>(buyer_addr, coin::mint<AptosCoin>(bid_price, &mint_cap));

//     // Get the marketplace signer's address
//     let marketplace_signer_addr = marketplace::get_marketplace_signer_addr();

//     // Create account for the marketplace signer's address
//     account::create_account_for_test(marketplace_signer_addr);

//     // Register the marketplace signer's address for AptosCoin
//     coin::register<AptosCoin>(&marketplace::get_marketplace_signer());

//     // Make a bid
//     marketplace::make_bid<AptosCoin>(buyer, bid_price, token_id);

//     // Accept the bid
//     marketplace::accept_bid<AptosCoin>(creator, token_id);

//     // Verify the NFT is transferred to the buyer
//     let nft_object = object::address_to_object<nft::NFT>(token_id);
//     debug::print(&string::utf8(b"test_accept_bid => nft_object:"));
//     debug::print(&nft_object);
//     assert!(object::owner(nft_object) == buyer_addr, 0);

//     // Verify that the listing no longer exists
//     assert!(!marketplace::exists_listing(listing_addr), 1); // Use listing_addr for the check

//     // Verify that the seller received the funds
//     let seller_balance = coin::balance<AptosCoin>(signer::address_of(creator));
//     assert!(seller_balance == bid_price, 2);

//     // Verify that the buyer's balance has decreased
//     let buyer_balance = coin::balance<AptosCoin>(buyer_addr);
//     assert!(buyer_balance == 0, 3);

//     // Clean up
//     coin::destroy_burn_cap<AptosCoin>(burn_cap);
//     coin::destroy_mint_cap<AptosCoin>(mint_cap);
// }
