module reward_addr::reward {
    use std::signer;
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_framework::table::{Self, Table};
    use aptos_framework::object::{Self};
    use mdtn_addr::mdtn;
    use std::debug;

    const ENOT_ADMIN: u64 = 1;
    const EDROP_NOT_STARTED: u64 = 3;
    const EDROP_ALREADY_STARTED: u64 = 4;
    const ENOT_FOUND: u64 = 5;
    const ALREADY_INIT: u64 = 6;

    #[event]
    struct ChangeAdmin has drop, store {
        prev_admin: address,
        new_admin: address
    }

    #[event]
    struct RewardEvent has drop, store {
        amount: u64,
        end_time: u64,
        nft_id: address,
        is_active: bool
    }

    #[event]
    struct RewardsExecuteEvent has drop, store {
        nft_id: address,
        total_sum: u64,
        per_address_amount: u64,
        addresses_for_rewards: vector<address>
    }

    struct RewardConfig has key, store, drop {
        amount: u64,
        end_time: u64,
        nft_id: address,
        addresses: Option<vector<address>>,
        is_active: bool
    }

    struct RewardMap has key {
        map: Table<address, RewardConfig>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Admin has key {
        admin: address
    }

    public entry fun init_admin(admin: &signer) {
        move_to(admin, Admin { admin: signer::address_of(admin) });
        move_to(admin, RewardMap { map: table::new() });
    }

    #[view]
    public fun get_admin_address(current_admin: address): address acquires Admin {
        let admin_info = borrow_global<Admin>(current_admin);
        admin_info.admin
    }

    public entry fun change_admin(
        current_admin: &signer, new_admin: address
    ) acquires Admin {
        let admin_info = borrow_global_mut<Admin>(signer::address_of(current_admin));
        assert!(signer::address_of(current_admin) == admin_info.admin, ENOT_ADMIN);
        admin_info.admin = new_admin;
        let admin_event = ChangeAdmin {
            prev_admin: signer::address_of(current_admin),
            new_admin
        };
        0x1::event::emit(admin_event);
    }

    public entry fun setup_reward(
        admin: &signer,
        owner_address: address,
        amount: u64,
        end_time: u64,
        nft_id: address
    ) acquires RewardMap, Admin {
        let admin_info = borrow_global<Admin>(owner_address);
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let reward_map = borrow_global_mut<RewardMap>(owner_address);
        let config = RewardConfig {
            amount,
            end_time,
            nft_id,
            addresses: option::none(),
            is_active: false
        };

        table::add(&mut reward_map.map, nft_id, config);
        let reward_event = RewardEvent { amount, end_time, nft_id, is_active: false };
        0x1::event::emit(reward_event);
    }

    public entry fun set_addresses(
        admin: &signer,
        owner_address: address,
        nft_id: address,
        addresses: vector<address>
    ) acquires RewardMap, Admin {
        let admin_info = borrow_global<Admin>(owner_address);
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let reward_map = borrow_global_mut<RewardMap>(owner_address);
        assert!(table::contains(&reward_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow_mut(&mut reward_map.map, nft_id);
        assert!(timestamp::now_seconds() > config.end_time, EDROP_NOT_STARTED);
        assert!(!config.is_active, EDROP_ALREADY_STARTED);

        config.addresses = option::some(addresses);
    }

    public entry fun execute_reward(
        admin: &signer, owner_address: address, nft_id: address
    ) acquires RewardMap, Admin {
        let admin_info = borrow_global<Admin>(owner_address);
        assert!(signer::address_of(admin) == admin_info.admin, ENOT_ADMIN);

        let reward_map = borrow_global_mut<RewardMap>(owner_address);
        assert!(table::contains(&reward_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow_mut(&mut reward_map.map, nft_id);
        assert!(option::is_some(&config.addresses), EDROP_NOT_STARTED);

        let addresses = option::extract(&mut config.addresses);
        let count = vector::length(&addresses);
        assert!(count > 0, EDROP_NOT_STARTED);

        let per_address_amount = config.amount / count;
        mdtn::mint(admin, signer::address_of(admin), config.amount);

        let i = 0;
        while (i < count) {
            let recipient = *vector::borrow(&addresses, i);
            mdtn::transfer(admin, recipient, per_address_amount);
            i = i + 1;
        };

        config.is_active = true;
        let rewards_execute_event = RewardsExecuteEvent {
            nft_id,
            total_sum: config.amount,
            per_address_amount,
            addresses_for_rewards: addresses
        };

        0x1::event::emit(rewards_execute_event);

    }

    #[view]
    public fun get_reward_info(
        nft_id: address, admin: address
    ): (u64, u64, address, bool) acquires RewardMap {
        let reward_map = borrow_global<RewardMap>(admin);
        assert!(table::contains(&reward_map.map, nft_id), ENOT_FOUND);

        let config = table::borrow(&reward_map.map, nft_id);
        (config.amount, config.end_time, config.nft_id, config.is_active)
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_admin(deployer);
    }
}
