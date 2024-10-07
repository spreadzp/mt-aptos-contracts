module mdtn_addr::mdtn {
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{
        Self,
        MintRef,
        TransferRef,
        BurnRef,
        Metadata,
        FungibleStore,
        FungibleAsset,
    };
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::function_info::{Self, FunctionInfo};
    use std::signer;
    use std::option;
    use std::event;
    use std::string::{Self, utf8};
    use std::vector;

    /* Errors */
    const EUNAUTHORIZED: u64 = 1;
    const ELOW_AMOUNT: u64 = 2;
    const ENOT_ADMIN: u64 = 3;
    const EROLE_EXISTS: u64 = 4;
    const EROLE_DOESNT_EXIST: u64 = 5;

    /* Constants */
    const ASSET_NAME: vector<u8> = b"Modern Talking Asset";
    const ASSET_SYMBOL: vector<u8> = b"MDTN";
    const TAX_RATE: u64 = 10;
    const SCALE_FACTOR: u64 = 100;

    /* Resources */
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Management has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        admins: vector<address>,
        mint_roles: vector<address>,
        burn_roles: vector<address>
    }

    /* Events */
    #[event]
    struct Mint has drop, store {
        minter: address,
        to: address,
        amount: u64
    }

    #[event]
    struct Burn has drop, store {
        burner: address,
        from: address,
        amount: u64
    }

    #[event]
    struct AdminAdded has drop, store {
        new_admin: address
    }

    #[event]
    struct RoleGranted has drop, store {
        account: address,
        role: vector<u8>
    }

    /* View Functions */
    #[view]
    public fun metadata_address(): address {
        object::create_object_address(&@mdtn_addr, ASSET_SYMBOL)
    }

    #[view]
    public fun metadata(): Object<Metadata> {
        object::address_to_object(metadata_address())
    }

    #[view]
    public fun deployer_store(): Object<FungibleStore> {
        primary_fungible_store::ensure_primary_store_exists(@mdtn_addr, metadata())
    }

    #[view]
    public fun is_admin(account: address): bool acquires Management {
        let management = borrow_global<Management>(metadata_address());
        vector::contains(&management.admins, &account)
    }

    /* Initialization */
    fun init_module(deployer: &signer) {
        let constructor_ref = &object::create_named_object(deployer, ASSET_SYMBOL);
        
        // Create fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(ASSET_NAME),
            utf8(ASSET_SYMBOL),
            8,
            utf8(b"https://example.com/icon.jpg"),
            utf8(b"https://example.com/icon.jpg")
        );

        let metadata_object_signer = &object::generate_signer(constructor_ref);
        let deployer_address = signer::address_of(deployer);

        // Initialize management with deployer as initial admin
        let initial_admins = vector::empty();
        vector::push_back(&mut initial_admins, deployer_address);

        move_to(
            metadata_object_signer,
            Management {
                extend_ref: object::generate_extend_ref(constructor_ref),
                mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
                admins: initial_admins,
                mint_roles: vector::empty(),
                burn_roles: vector::empty()
            }
        );

        // Register withdraw function for tax handling
        let withdraw_function = function_info::new_function_info(
            deployer,
            string::utf8(b"mdtn"),
            string::utf8(b"withdraw")
        );

        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw_function),
            option::none(),
            option::none()
        );
    }

    /* Admin Management */
    public entry fun add_admin(admin: &signer, new_admin: address) acquires Management {
        let management = borrow_global_mut<Management>(metadata_address());
        assert!(vector::contains(&management.admins, &signer::address_of(admin)), ENOT_ADMIN);
        assert!(!vector::contains(&management.admins, &new_admin), EROLE_EXISTS);
        
        vector::push_back(&mut management.admins, new_admin);
        event::emit(AdminAdded { new_admin });
    }

    public entry fun grant_mint_role(admin: &signer, account: address) acquires Management {
        let management = borrow_global_mut<Management>(metadata_address());
        assert!(vector::contains(&management.admins, &signer::address_of(admin)), ENOT_ADMIN);
        assert!(!vector::contains(&management.mint_roles, &account), EROLE_EXISTS);
        
        vector::push_back(&mut management.mint_roles, account);
        event::emit(RoleGranted { account, role: b"mint" });
    }

    public entry fun grant_burn_role(admin: &signer, account: address) acquires Management {
        let management = borrow_global_mut<Management>(metadata_address());
        assert!(vector::contains(&management.admins, &signer::address_of(admin)), ENOT_ADMIN);
        assert!(!vector::contains(&management.burn_roles, &account), EROLE_EXISTS);
        
        vector::push_back(&mut management.burn_roles, account);
        event::emit(RoleGranted { account, role: b"burn" });
    }

    /* Asset Operations */
    public fun withdraw(store: Object<FungibleStore>, amount: u64, transfer_ref: &TransferRef): FungibleAsset {
        let tax = (amount * TAX_RATE) / SCALE_FACTOR;
        let remaining_amount = amount - tax;

        let tax_assets = fungible_asset::withdraw_with_ref(transfer_ref, store, tax);
        fungible_asset::deposit_with_ref(transfer_ref, deployer_store(), tax_assets);

        fungible_asset::withdraw_with_ref(transfer_ref, store, remaining_amount)
    }

    public entry fun mint(minter: &signer, to: address, amount: u64) acquires Management {
        let management = borrow_global<Management>(metadata_address());
        let minter_address = signer::address_of(minter);
        
        assert!(
            vector::contains(&management.admins, &minter_address) || 
            vector::contains(&management.mint_roles, &minter_address),
            EUNAUTHORIZED
        );

        let assets = fungible_asset::mint(&management.mint_ref, amount);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(to, metadata());
        fungible_asset::deposit_with_ref(&management.transfer_ref, recipient_store, assets);

        event::emit(Mint { minter: minter_address, to, amount });
    }

    public entry fun burn(burner: &signer, from: address, amount: u64) acquires Management {
        let management = borrow_global<Management>(metadata_address());
        let burner_address = signer::address_of(burner);
        
        assert!(
            vector::contains(&management.admins, &burner_address) || 
            vector::contains(&management.burn_roles, &burner_address),
            EUNAUTHORIZED
        );

        let from_store = primary_fungible_store::ensure_primary_store_exists(from, metadata());
        let assets = fungible_asset::withdraw_with_ref(&management.transfer_ref, from_store, amount);
        fungible_asset::burn(&management.burn_ref, assets);

        event::emit(Burn { burner: burner_address, from, amount });
    }

    public entry fun transfer(from: &signer, to: address, amount: u64) acquires Management {
        let management = borrow_global<Management>(metadata_address());
        let from_store = primary_fungible_store::ensure_primary_store_exists(
            signer::address_of(from),
            metadata()
        );
        let to_store = primary_fungible_store::ensure_primary_store_exists(to, metadata());
        
        let assets = withdraw(from_store, amount, &management.transfer_ref);
        fungible_asset::deposit_with_ref(&management.transfer_ref, to_store, assets);
    }

    /* Helper Functions */
    #[test_only]
    public fun register_account(account: &signer) {
        primary_fungible_store::ensure_primary_store_exists(
            signer::address_of(account),
            metadata()
        );
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
    }
}