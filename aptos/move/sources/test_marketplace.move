#[test_only]
module marketplace_addr::test_marketplace {
    use std::signer;
    use std::string::{Self};
    use std::option;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use nft_addr::nft;
    use marketplace_addr::marketplace;
    use std::debug;
    use std::vector;
    use aptos_framework::table::{Self, Table}; // Import the table module
    use aptos_framework::stake;
    use aptos_framework::event;

    // Test minting (initializing) an NFT
    #[test(creator = @0x1)]
    public entry fun test_mint_nft(creator: &signer) {
        account::create_account_for_test(signer::address_of(creator));

        let metadata = string::utf8(b"https://example.com/nft1");
        let token_id = nft::test_initialize_nft(creator, metadata);

        assert!(nft::get_creator(token_id) == signer::address_of(creator), 0);
        assert!(nft::get_metadata_hash_by_id(token_id) == metadata, 1);
    }

    // Test metadata mapping
    #[test(creator = @0x1)]
    public entry fun test_metadata_mapping(creator: &signer) {
        account::create_account_for_test(signer::address_of(creator));

        let metadata = string::utf8(b"0x12345abc");
        let token_id = nft::test_initialize_nft(creator, metadata);

        let creator_addr = signer::address_of(creator);
        let retrieved_token_id = nft::get_nft_id_by_hash(metadata, creator_addr);
        assert!(retrieved_token_id == token_id, 0);
    }

    // Test transferring an NFT
    #[test(creator = @0x1, recipient = @0x2)]
    public entry fun test_transfer_nft(creator: &signer, recipient: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        account::create_account_for_test(signer::address_of(recipient));

        let metadata = string::utf8(b"https://example.com/nft3");
        let token_id = nft::test_initialize_nft(creator, metadata);

        // Transfer the NFT
        nft::test_transfer(creator, signer::address_of(recipient), token_id);

        // Verify the transfer
        let object = object::address_to_object<nft::NFT>(token_id);
        assert!(object::owner(object) == signer::address_of(recipient), 0);
    }

    // Test minting multiple NFTs
    #[test(creator = @0x1)]
    public entry fun test_mint_multiple_nfts(creator: &signer) {
        account::create_account_for_test(signer::address_of(creator));

        let metadata1 = string::utf8(b"https://example.com/nft4");
        let metadata2 = string::utf8(b"https://example.com/nft5");

        let token_id1 = nft::test_initialize_nft(creator, metadata1);
        let token_id2 = nft::test_initialize_nft(creator, metadata2);

        assert!(token_id1 != token_id2, 0);
        assert!(nft::get_metadata_hash_by_id(token_id1) == metadata1, 1);
        assert!(nft::get_metadata_hash_by_id(token_id2) == metadata2, 2);
    }

    #[test(creator = @0x1)]
    #[expected_failure(abort_code = 393219, location = nft_addr::nft)]
    public entry fun test_get_non_existent_nft(creator: &signer) {
        account::create_account_for_test(signer::address_of(creator));

        // Initialize an NFT to ensure the MetadataMap is created and populated
        let metadata = string::utf8(b"0x122abc");
        let token_id = nft::test_initialize_nft(creator, metadata);

        // Ensure the metadata is added to the table
        let creator_addr = signer::address_of(creator);
        let retrieved_token_id = nft::get_nft_id_by_hash(metadata, creator_addr);
        assert!(retrieved_token_id == token_id, 2);

        let non_existent_metadata = string::utf8(b"0x123abcd");
        let _token_id = nft::get_nft_id_by_hash(non_existent_metadata, creator_addr);
    }

    // Test listing an NFT for sale at a fixed price
    #[test(creator = @0x1, marketplace = @marketplace_addr)]
    public entry fun test_list_nft_with_fixed_price(creator: &signer, marketplace: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        marketplace::setup_test(marketplace);

        let metadata = string::utf8(b"https://example.com/nft6");
        let token_id = nft::test_initialize_nft(creator, metadata);
        let price_for_sell = 1000;
        marketplace::list_nft_with_fixed_price(creator, token_id, price_for_sell);

        let listing_addr = marketplace::get_nft_listing(token_id);
        let listing_info = marketplace::get_listing_info(signer::address_of(creator));
        debug::print(&listing_info);

        // Use the public function to get the fields as a tuple
        let (object_address, seller, price) = marketplace::get_listing_info_fields(&listing_info);

        // Assert the values
        assert!(object_address == token_id, 1);
        assert!(seller == signer::address_of(creator), 2);
        assert!(price == price_for_sell, 3);
    } 

    #[test(creator = @0x1, marketplace = @marketplace_addr, unauthorized_user = @0x3)]
    #[expected_failure(abort_code = 327682, location = marketplace_addr::marketplace)]
    public entry fun test_list_nft_without_ownership(creator: &signer, marketplace: &signer, unauthorized_user: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        account::create_account_for_test(signer::address_of(unauthorized_user));
        marketplace::setup_test(marketplace);

        let metadata = string::utf8(b"https://example.com/nft7");
        let token_id = nft::test_initialize_nft(creator, metadata);
        let price_for_sell = 1000;

        // Attempt to list the NFT with an unauthorized user
        marketplace::list_nft_with_fixed_price(unauthorized_user, token_id, price_for_sell);
    }

    // Negative Test: Listing an NFT with zero price
    #[test(creator = @0x1, marketplace = @marketplace_addr)]
    #[expected_failure(abort_code = 327688, location = marketplace_addr::marketplace)]
    public entry fun test_list_nft_with_zero_price(creator: &signer, marketplace: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        marketplace::setup_test(marketplace);

        let metadata = string::utf8(b"https://example.com/nft8");
        let token_id = nft::test_initialize_nft(creator, metadata);
        let price_for_sell = 0;

        // Attempt to list the NFT with a zero price
        marketplace::list_nft_with_fixed_price(creator, token_id, price_for_sell);
    }

    // Positive Test: Listing an NFT and parsing the event
    #[test(creator = @0x1, marketplace = @marketplace_addr)]
    public entry fun test_list_nft_and_parse_event(creator: &signer, marketplace: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        marketplace::setup_test(marketplace);

        let metadata = string::utf8(b"https://example.com/nft9");
        let token_id = nft::test_initialize_nft(creator, metadata);
        let price_for_sell = 1000;

        // List the NFT
        marketplace::list_nft_with_fixed_price(creator, token_id, price_for_sell);

        // Parse the event and check the values
        let events = marketplace::get_listing_events();
        //let event = vector::borrow(&events, 0);
        debug::print(&events);
        //assert!(event.type_tag == type_tag_for<marketplace::ListingEvent>(), 1);
        //let listing_event = option::extract(&mut event.data);
        //assert!(listing_event.nft_id == token_id, 2);
        //assert!(listing_event.price == price_for_sell, 3);
    }

    // Positive Test: Listing an NFT and checking the `table::upsert` operation
    #[test(creator = @0x1, marketplace = @marketplace_addr)]
    public entry fun test_list_nft_and_check_table_upsert(creator: &signer, marketplace: &signer) {
        account::create_account_for_test(signer::address_of(creator));
        marketplace::setup_test(marketplace);

        let metadata = string::utf8(b"https://example.com/nft10");
        let token_id = nft::test_initialize_nft(creator, metadata);
        let price_for_sell = 1000;

        // List the NFT
        marketplace::list_nft_with_fixed_price(creator, token_id, price_for_sell);

        // Check the `table::upsert` operation
        let seller_addr = signer::address_of(creator);
        let metadata_hash = nft::get_metadata_hash_by_id(token_id);
        let listing_addr = marketplace::get_nft_listing(token_id);
        //let listing_addr = *table::borrow(&listing_map.map, metadata_hash);
        assert!(listing_addr == token_id, 1);
    } 
}