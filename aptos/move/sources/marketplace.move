module marketplace_addr::marketplace {
    use std::error;
    use std::signer;
    use std::option;
    use aptos_framework::coin::{Self};
    use aptos_framework::object::{Self, Object};
    use nft_addr::nft;
    use std::string::String;
    use std::vector;
    use std::table::{Self, Table};
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;

    const APP_OBJECT_SEED: vector<u8> = b"MARKETPLACE";

    const ENO_LISTING: u64 = 1;
    const ENO_SELLER: u64 = 2;
    const EINSUFFICIENT_BALANCE: u64 = 3;
    const ENO_NFT: u64 = 4;
    const ENOT_AUTHORIZED: u64 = 5;
    const EINSUFFICIENT_BID_AMOUNT: u64 = 6;
    const EBID_NOT_FOUND: u64 = 7;
    const ZERO_PRICE: u64 = 8;

    const STATUS_CREATED: u8 = 0;
    const STATUS_ACCEPTED: u8 = 1;
    const STATUS_CHANGE_PRICE: u8 = 2;
    const STATUS_CANCELLED: u8 = 3;

    struct MarketplaceSigner has key {
        extend_ref: object::ExtendRef
    }

    struct Sellers has key {
        addresses: vector<address>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ListingWithPrice has key, drop {
        object: object::Object<object::ObjectCore>,
        seller: address,
        delete_ref: object::DeleteRef,
        extend_ref: object::ExtendRef,
        price: u64,
        transfer_ref: object::TransferRef,
        listing_event: ListingEvent
    }

    #[event]
    struct ListingEvent has drop, store, copy {
        nft_id: address,
        price: u64,
        listing_addr: address,
        status: u8
    }

    struct SellerListings has key, store {
        listings: vector<address>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ListingAddressMap has key {
        map: Table<String, address>
    }

    struct ListingInfo has copy, drop, store {
        object_address: address,
        seller: address,
        price: u64
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Offer has key, store, drop {
        object: object::Object<object::ObjectCore>,
        buyer: address,
        price: u64,
        transfer_ref: object::TransferRef
    }

    fun init_module(deployer: &signer) {
        let constructor_ref = object::create_named_object(
            deployer, APP_OBJECT_SEED
        );
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let marketplace_signer = &object::generate_signer(&constructor_ref);

        move_to(marketplace_signer, MarketplaceSigner { extend_ref });

        move_to(marketplace_signer, Sellers { addresses: vector::empty() });
    }

    fun init_listing_addr_map() acquires MarketplaceSigner {
        if (!exists<ListingAddressMap>(get_marketplace_signer_addr())) {
            move_to(&get_marketplace_signer(), ListingAddressMap { map: table::new() });
        }
    }

    public entry fun list_nft_with_fixed_price(
        seller: &signer,
        nft_id: address,
        price: u64
    ) acquires SellerListings, MarketplaceSigner, ListingAddressMap {
        let nft_object = object::address_to_object<nft::NFT>(nft_id);
        assert!(price > 0, error::permission_denied(ZERO_PRICE));
        assert!(
            nft::get_owner_by_id(nft_id) == signer::address_of(seller),
            error::permission_denied(ENO_SELLER)
        );
        list_with_fixed_price_internal(seller, object::convert(nft_object), price);
    }

    public(friend) fun list_with_fixed_price_internal(
        seller: &signer,
        object: Object<object::ObjectCore>,
        price: u64
    ) acquires SellerListings, MarketplaceSigner, ListingAddressMap {
        init_listing_addr_map();

        let constructor_ref = object::create_object(signer::address_of(seller));
        let listing_addr = object::object_address(&object);
        let listing_event = ListingEvent {
            nft_id: object::object_address(&object),
            price,
            listing_addr,
            status: STATUS_CREATED
        };
        let listing_with_price = ListingWithPrice {
            object,
            seller: signer::address_of(seller),
            delete_ref: object::generate_delete_ref(&constructor_ref),
            extend_ref: object::generate_extend_ref(&constructor_ref),
            price,
            transfer_ref: object::generate_transfer_ref(&constructor_ref),
            listing_event
        };

        let listing_signer =
            object::generate_signer_for_extending(&listing_with_price.extend_ref);
        move_to(seller, listing_with_price);
        object::transfer(seller, object, signer::address_of(&listing_signer));

        if (!exists<SellerListings>(signer::address_of(seller))) {
            move_to(
                seller,
                SellerListings {
                    listings: vector::empty<address>()
                }
            );
        };

        let seller_listings =
            borrow_global_mut<SellerListings>(signer::address_of(seller));
        vector::push_back(&mut seller_listings.listings, listing_addr);

        let seller_addr = signer::address_of(seller);
        if (!exists<ListingAddressMap>(seller_addr)) {
            move_to(seller, ListingAddressMap { map: table::new() });
        };

        let metadata_hash = nft::get_metadata_hash_by_id(object::object_address(&object));
        let listing_address_map = borrow_global_mut<ListingAddressMap>(seller_addr);
        table::upsert(&mut listing_address_map.map, metadata_hash, listing_addr);

        0x1::event::emit(listing_event);
    }

    public fun exists_listing(listing_id: address): bool {
        exists<ListingWithPrice>(listing_id)
    }

    #[view]
    public fun price(
        object: object::Object<ListingWithPrice>
    ): option::Option<u64> acquires ListingWithPrice {
        let listing_addr = object::object_address(&object);
        if (exists<ListingWithPrice>(listing_addr)) {
            let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
            option::some(listing_with_price.price)
        } else {
            option::none()
        }
    }

    #[view]
    public fun listing(listing_addr: address): option::Option<ListingInfo> acquires ListingWithPrice {
        if (exists<ListingWithPrice>(listing_addr)) {
            let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
            option::some(
                ListingInfo {
                    object_address: object::object_address(&listing_with_price.object),
                    seller: listing_with_price.seller,
                    price: listing_with_price.price
                }
            )
        } else {
            option::none()
        }
    }

    #[view]
    public fun get_seller_listings(seller: address): vector<address> acquires SellerListings {
        let seller_listings = borrow_global<SellerListings>(seller);
        // Return a reference to the vector without dereferencing
        seller_listings.listings
    }

    #[view]
    public fun get_seller_listings_length(seller: address): u64 acquires SellerListings {
        let seller_listings = borrow_global<SellerListings>(seller);
        vector::length(&seller_listings.listings)
    }

    #[view]
    public fun get_sellers(): vector<address> acquires Sellers {
        assert!(
            exists<Sellers>(get_marketplace_signer_addr()), error::not_found(ENO_SELLER)
        );
        borrow_global<Sellers>(get_marketplace_signer_addr()).addresses
    }

    #[view]
    public fun get_sellers_count(): u64 acquires Sellers {
        if (!exists<Sellers>(get_marketplace_signer_addr())) {
            return 0
        };
        let sellers = borrow_global<Sellers>(get_marketplace_signer_addr());
        vector::length(&sellers.addresses)
    }

    #[view]
    public fun get_seller_at(index: u64): address acquires Sellers {
        assert!(
            exists<Sellers>(get_marketplace_signer_addr()), error::not_found(ENO_SELLER)
        );
        let sellers = borrow_global<Sellers>(get_marketplace_signer_addr());
        *vector::borrow(&sellers.addresses, index)
    }

    #[view]
    public fun get_nft_listing(nft_id: address): address acquires ListingAddressMap {
        let seller = nft::get_owner_by_id(nft_id);
        let metadata_hash = nft::get_metadata_hash_by_id(nft_id);
        assert!(exists<ListingAddressMap>(seller), error::not_found(ENO_LISTING));
        let listing_map = borrow_global<ListingAddressMap>(seller);
        *table::borrow(&listing_map.map, metadata_hash)
    }

    #[view]
    public fun get_listing_object_address(listing_addr: address): address acquires ListingWithPrice {
        let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
        object::object_address(&listing_with_price.object)
    }

    #[view]
    public fun get_listing_seller(listing_addr: address): address acquires ListingWithPrice {
        let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
        listing_with_price.seller
    }

    #[view]
    public fun get_listing_price(listing_addr: address): u64 acquires ListingWithPrice {
        let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
        listing_with_price.price
    }

    #[view]
    public fun get_offer_id_by_nft_id(
        nft_id: address
    ): option::Option<address> acquires ListingAddressMap {
        let seller = nft::get_owner_by_id(nft_id);
        let metadata_hash = nft::get_metadata_hash_by_id(nft_id);
        if (exists<ListingAddressMap>(seller)) {
            let listing_map = borrow_global<ListingAddressMap>(seller);
            if (table::contains(&listing_map.map, metadata_hash)) {
                option::some(*table::borrow(&listing_map.map, metadata_hash))
            } else {
                option::none()
            }
        } else {
            option::none()
        }
    }

    #[test_only]
    public fun setup_test(marketplace: &signer) {
        init_module(marketplace);
    }

    public fun get_marketplace_signer_addr(): address {
        object::create_object_address(&@marketplace_addr, APP_OBJECT_SEED)
    }

    public fun get_marketplace_signer(): signer acquires MarketplaceSigner {
        object::generate_signer_for_extending(
            &borrow_global<MarketplaceSigner>(get_marketplace_signer_addr()).extend_ref
        )
    }

    #[test_only]
    public fun get_listing_info(listing_addr: address): ListingInfo acquires ListingWithPrice {
        let listing_with_price = borrow_global<ListingWithPrice>(listing_addr);
        ListingInfo {
            object_address: object::object_address(&listing_with_price.object),
            seller: listing_with_price.seller,
            price: listing_with_price.price
        }
    }

    #[test_only]
    public fun get_listing_with_price(owner: address): ListingWithPrice acquires ListingWithPrice {
        move_from<ListingWithPrice>(owner)
    }

    #[test_only]
    public fun get_listing_info_by_address(
        listing_addr: address
    ): ListingInfo acquires ListingWithPrice {
        let listing_with_price = move_from<ListingWithPrice>(listing_addr);
        let result = ListingInfo {
            object_address: object::object_address(&listing_with_price.object),
            seller: listing_with_price.seller,
            price: listing_with_price.price
        };
        result
    }

    #[test_only]
    public fun get_listing_info_fields(listing_info: &ListingInfo): (address, address, u64) {
        (listing_info.object_address, listing_info.seller, listing_info.price)
    }

    // Helper function to get listing address map
    #[test_only]
    public fun get_listing_address_map(seller_addr: address): Table<String, address> {
        let listing_map = table::new<String, address>();
        // Simulate fetching the listing address map from the blockchain
        // This is a placeholder for the actual implementation
        listing_map
    }

    public entry fun claim_offer_by_owner_nft(
        owner: &signer, offer_id: address
    ) acquires Offer, ListingWithPrice {
        let offer = borrow_global<Offer>(offer_id);
        assert!(
            offer.buyer == signer::address_of(owner),
            error::permission_denied(ENOT_AUTHORIZED)
        );

        let listing_addr = object::object_address(&offer.object);
        let listing_with_price = borrow_global_mut<ListingWithPrice>(listing_addr);
        assert!(
            listing_with_price.seller == signer::address_of(owner),
            error::permission_denied(ENOT_AUTHORIZED)
        );

        // Transfer the NFT to the buyer
        let obj = object::address_to_object<Offer>(listing_addr);
        object::transfer(owner, obj, offer.buyer);

        // Update the status of the listing
        listing_with_price.listing_event.status = STATUS_ACCEPTED;

        // Emit the event
        0x1::event::emit(listing_with_price.listing_event);

        // Remove the offer
        move_from<Offer>(offer_id);
    }

    public entry fun accept_offer(
        buyer: &signer,
        seller: address,
        offer_id: address
    ) acquires Offer, ListingWithPrice {
        let offer = borrow_global<Offer>(offer_id);
        let listing_addr = object::object_address(&offer.object);
        let listing_with_price = borrow_global_mut<ListingWithPrice>(listing_addr);

        //assert!(listing_with_price.seller == signer::address_of(seller), error::permission_denied(ENOT_AUTHORIZED));
        assert!(
            coin::balance<AptosCoin>(offer.buyer) >= offer.price,
            error::invalid_argument(EINSUFFICIENT_BID_AMOUNT)
        );

        let obj_signer =
            object::generate_signer_for_extending(&listing_with_price.extend_ref);
        let obj = object::address_to_object<Offer>(listing_addr);
        object::transfer(&obj_signer, obj, signer::address_of(buyer));
        // Transfer the NFT to the buyer
        //object::transfer_with_ref(offer.transfer_ref, signer::address_of(buyer));

        // Transfer APT coins to the seller
        aptos_account::transfer_coins<AptosCoin>(buyer, seller, offer.price);

        // Update the status of the listing
        listing_with_price.listing_event.status = STATUS_ACCEPTED;

        // Emit the event
        0x1::event::emit(listing_with_price.listing_event);

        // Remove the offer
        move_from<Offer>(offer_id);

        // Remove the listing
        move_from<ListingWithPrice>(listing_addr);
    }

    public entry fun close_offer(owner: &signer, offer_id: address) acquires Offer, ListingWithPrice {
        let offer = borrow_global<Offer>(offer_id);
        assert!(
            offer.buyer == signer::address_of(owner),
            error::permission_denied(ENOT_AUTHORIZED)
        );

        let listing_addr = object::object_address(&offer.object);
        let listing_with_price = borrow_global_mut<ListingWithPrice>(listing_addr);

        // Update the status of the listing
        listing_with_price.listing_event.status = STATUS_CANCELLED;

        // Emit the event
        0x1::event::emit(listing_with_price.listing_event);

        // Remove the offer
        move_from<Offer>(offer_id);
    }

    public entry fun change_price_offer(
        owner: &signer,
        offer_id: address,
        new_price: u64
    ) acquires Offer, ListingWithPrice {
        let offer = borrow_global_mut<Offer>(offer_id);
        assert!(
            offer.buyer == signer::address_of(owner),
            error::permission_denied(ENOT_AUTHORIZED)
        );
        assert!(new_price > 0, error::invalid_argument(ZERO_PRICE));

        let listing_addr = object::object_address(&offer.object);
        let listing_with_price = borrow_global_mut<ListingWithPrice>(listing_addr);

        // Update the price and status of the listing
        listing_with_price.price = new_price;
        listing_with_price.listing_event.status = STATUS_CHANGE_PRICE;

        // Emit the event
        0x1::event::emit(listing_with_price.listing_event);

        offer.price = new_price;
    }

    #[test_only]
    public fun get_listing_events(): vector<ListingEvent> {
        let events = vector::empty<ListingEvent>();
        // In a real implementation, you would fetch events from the blockchain
        // For testing purposes, we'll create a sample event
        let sample_event = ListingEvent {
            nft_id: @0x123,
            price: 1000,
            listing_addr: @0x456,
            status: STATUS_CREATED
        };
        vector::push_back(&mut events, sample_event);
        events
    }

    #[test_only]
    public fun test_create_offer(
        buyer: &signer, nft_id: address, price: u64
    ): address acquires ListingAddressMap {
        let offer_id_option = get_offer_id_by_nft_id(nft_id);
        assert!(option::is_some(&offer_id_option), 0);
        let offer_id = option::extract(&mut offer_id_option);
        offer_id
    }
}
