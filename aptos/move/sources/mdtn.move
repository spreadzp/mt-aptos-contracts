module mdtn_addr::mdtn {
    use std::signer;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability, FreezeCapability};
    use std::string::{String};
    use std::option::Option;
    use std::event;

    /// Struct representing the MDTN coin
    struct MDTN has key {}

    /// Struct to store the admin's address and mint capabilities
    struct AdminConfig has key {
        admin: address,
        mint_cap: MintCapability<MDTN>,
        freeze_cap: FreezeCapability<MDTN>,
        burn_cap: BurnCapability<MDTN>,
    }

    const ENOT_ADMIN: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;

    #[event]
    struct MintEvent has copy, store, drop {
        amount: u64,
        to: address,
    }

    #[event]
    struct BurnEvent has copy, store, drop {
        amount: u64,
        from: address,
    }

    #[event]
    struct TransferEvent has copy, store, drop {
        amount: u64,
        from: address,
        to: address,
    }

    #[event]
    struct WithdrawEvent has copy, store, drop {
        amount: u64,
        from: address,
    }

    /// Initialize the MDTN token and set the creator as the admin
    public entry fun initialize(creator: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MDTN>(
            creator,
            std::string::utf8(b"Modern Talking"),
            std::string::utf8(b"MDTN"),
            8,
            false
        );
        let admin = signer::address_of(creator);
        move_to(creator, AdminConfig { admin, mint_cap, freeze_cap, burn_cap });
    }

    /// Function to change the admin, only callable by the current admin
    public entry fun change_admin(current_admin: &signer, new_admin: address) acquires AdminConfig {
        let config = borrow_global_mut<AdminConfig>(signer::address_of(current_admin));
        assert!(signer::address_of(current_admin) == config.admin, ENOT_ADMIN);
        config.admin = new_admin;
    }

    /// Public function to mint new tokens, only callable by the admin
    public entry fun mint(admin: &signer, amount: u64) acquires AdminConfig {
        let config = borrow_global<AdminConfig>(signer::address_of(admin));
        assert!(signer::address_of(admin) == config.admin, ENOT_ADMIN);
        let minted_coins = coin::mint<MDTN>(amount, &config.mint_cap);
        coin::deposit(signer::address_of(admin), minted_coins);

        event::emit(MintEvent { amount, to: signer::address_of(admin) });
    }

    /// Public function to burn tokens, only callable by the admin
    public entry fun burn(admin: &signer, amount: u64) acquires AdminConfig {
        let config = borrow_global<AdminConfig>(signer::address_of(admin));
        assert!(signer::address_of(admin) == config.admin, ENOT_ADMIN);
        let coins_to_burn = coin::withdraw<MDTN>(admin, amount);
        coin::burn<MDTN>(coins_to_burn, &config.burn_cap);

        event::emit(BurnEvent { amount, from: signer::address_of(admin) });
    }

    /// Public function to transfer MDTN from the admin to another address
    public entry fun transfer(admin: &signer, to: address, amount: u64) acquires AdminConfig {
        let config = borrow_global<AdminConfig>(signer::address_of(admin));
        assert!(signer::address_of(admin) == config.admin, ENOT_ADMIN);

        let admin_balance = coin::balance<MDTN>(signer::address_of(admin));
        assert!(admin_balance >= amount, EINSUFFICIENT_BALANCE);

        coin::transfer<MDTN>(admin, to, amount);

        event::emit(TransferEvent { amount, from: signer::address_of(admin), to });
    }

    /// Public function to withdraw MDTN tokens to another address, callable by any account
    public entry fun withdraw(account: &signer, to: address, amount: u64) {
        let balance = coin::balance<MDTN>(signer::address_of(account));
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);

        coin::transfer<MDTN>(account, to, amount);

        event::emit(WithdrawEvent { amount, from: signer::address_of(account) });
    }

    // #[view]
    // public entry fun register_account(account: &signer) {
    //     coin::register<MDTN>(account);
    // }

    #[view]
    public fun get_balance(addr: address): u64 {
        coin::balance<MDTN>(addr)
    }

    #[view]
    public fun metadata(): (String, String, u8, Option<u128>) {
        let name = coin::name<MDTN>();
        let symbol = coin::symbol<MDTN>();
        let decimals = coin::decimals<MDTN>();
        let supply = coin::supply<MDTN>();
        (name, symbol, decimals, supply)
    }

    #[view]
    public fun metadata_address(): address {
        @mdtn_addr
    }

    #[view]
    public fun get_admin(): address acquires AdminConfig {
        let config = borrow_global<AdminConfig>(@mdtn_addr);
        config.admin
    }
}