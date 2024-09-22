module airdrop_addr::airdrop {
    use std::signer;
    use std::vector;
    use std::option::{Self, Option}; 
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table};
    use mdtn_addr::mdtn;

    const ENOT_ADMIN: u64 = 1;
    const EDROP_NOT_STARTED: u64 = 3;
    const EDROP_ALREADY_STARTED: u64 = 4;
    const ENOT_FOUND: u64 = 5;

    /// Struct to hold the airdrop configuration for each NFT
    struct AirdropConfig has store {
        amount: u64,
        end_time: u64,
        nft_id: address,
        addresses: Option<vector<address>>,
        is_active: bool,
    }

    /// Table to map `nft_id` to its corresponding AirdropConfig
    struct AirdropMap has key {
        map: Table<address, AirdropConfig>,
    }

    /// Global admin address stored separately from AirdropConfig
    struct Admin has key {
        admin: address,
    }

    /// Initialize the contract with the admin address and an empty AirdropMap
    fun init_module(admin: &signer) {
        move_to(admin, Admin { admin: signer::address_of(admin) });
        move_to(admin, AirdropMap { map: table::new() });
    }

    /// Get the current admin address
    public fun get_admin_address(current_admin: address): address acquires Admin {
        let admin_info = borrow_global<Admin>(current_admin);
        admin_info.admin
    }

    /// Function to change the admin, only callable by the current admin
    public entry fun change_admin(current_admin: &signer, new_admin: address) acquires Admin {
        let admin_info = borrow_global_mut<Admin>(signer::address_of(current_admin));
        assert!(signer::address_of(current_admin) == admin_info.admin, ENOT_ADMIN);
        admin_info.admin = new_admin;
    }

    /// Function to create an airdrop for a specific `nft_id`, only callable by the admin
    public entry fun setup_airdrop(admin: &signer, amount: u64, end_time: u64, nft_id: address) acquires AirdropMap, Admin {
        let admin_info = borrow_global<Admin>(signer::address_of(admin));
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let airdrop_map = borrow_global_mut<AirdropMap>(signer::address_of(admin));
        let config = AirdropConfig {
            amount,
            end_time,
            nft_id,
            addresses: option::none(),
            is_active: false,
        };

        table::add(&mut airdrop_map.map, nft_id, config);
    }

    /// Set addresses for airdrop
    public entry fun set_addresses(admin: &signer, nft_id: address, addresses: vector<address>) acquires AirdropMap, Admin {
        let admin_info = borrow_global<Admin>(signer::address_of(admin));
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let airdrop_map = borrow_global_mut<AirdropMap>(signer::address_of(admin));
        assert!(table::contains(&airdrop_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow_mut(&mut airdrop_map.map, nft_id);
        assert!(timestamp::now_seconds() > config.end_time, EDROP_NOT_STARTED);
        assert!(!config.is_active, EDROP_ALREADY_STARTED);

        config.addresses = option::some(addresses);
    }

    /// Trigger the airdrop process, mint tokens, and distribute them equally
    public entry fun execute_airdrop(admin: &signer, nft_id: address) acquires AirdropMap, Admin {
        let admin_info = borrow_global<Admin>(signer::address_of(admin));
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let airdrop_map = borrow_global_mut<AirdropMap>(signer::address_of(admin));
        assert!(table::contains(&airdrop_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow_mut(&mut airdrop_map.map, nft_id);
        assert!(option::is_some(&config.addresses), EDROP_NOT_STARTED);

        let addresses = option::extract(&mut config.addresses);
        let count = vector::length(&addresses);
        assert!(count > 0, EDROP_NOT_STARTED);

        let per_address_amount = config.amount / count;
        mdtn::mint(admin,  config.amount);

        let i = 0;
        while (i < count) {
            let recipient = *vector::borrow(&addresses, i);
            // if (!coin::is_account_registered<mdtn::MDTN>(recipient)) {
            //     mdtn::register_account(admin);
            // };
            mdtn::transfer(admin, recipient, per_address_amount);
            i = i + 1;
        };

        config.is_active = true;
    }

    /// View function to check the airdrop configuration for a specific `nft_id`
    public fun get_airdrop_info(nft_id: address, admin: address): (u64, u64, address, bool) acquires AirdropMap {
        let airdrop_map = borrow_global<AirdropMap>(admin);
        assert!(table::contains(&airdrop_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow(&airdrop_map.map, nft_id);
        (config.amount, config.end_time, config.nft_id, config.is_active)
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
    }
}