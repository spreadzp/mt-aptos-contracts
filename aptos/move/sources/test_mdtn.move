#[test_only]
module mdtn_addr::test_mdtn {
    use aptos_framework::account;
    use aptos_framework::primary_fungible_store;
    use mdtn_addr::mdtn::{Self};

    // Error codes
    const ETEST_FAILED: u64 = 1;

    // Test accounts
    const ADMIN: address = @0xa11ce;
    const USER1: address = @0xb0b;
    const USER2: address = @0xca4;
    const NEW_ADMIN: address = @0xadd1e;
    const MINTER: address = @0x1234;
    const BURNER: address = @0x5678;

    // Test amount
    const MINT_AMOUNT: u64 = 1000;
    const TRANSFER_AMOUNT: u64 = 100;
    const BURN_AMOUNT: u64 = 50;

    // Helper function to setup test environment
    fun setup_test(): signer {
        let admin = account::create_account_for_test(ADMIN);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        let new_admin = account::create_account_for_test(NEW_ADMIN);
        let minter = account::create_account_for_test(MINTER);
        let burner = account::create_account_for_test(BURNER);

        mdtn::init_for_test(&admin);
        mdtn::register_account(&user1);
        mdtn::register_account(&user2);
        mdtn::register_account(&new_admin);
        mdtn::register_account(&minter);
        mdtn::register_account(&burner);

        admin
    }

    #[test]
    public fun test_initialization_success() {
        let admin = setup_test();
        assert!(mdtn::is_admin(ADMIN), ETEST_FAILED);
    }

    #[test]
    #[expected_failure(abort_code = mdtn::ENOT_ADMIN)]
    public fun test_add_admin_unauthorized() {
        let admin = setup_test();
        let unauthorized = account::create_account_for_test(USER1);
        mdtn::add_admin(&unauthorized, NEW_ADMIN);
    }

    #[test]
    public fun test_add_admin_success() {
        let admin = setup_test();
        mdtn::add_admin(&admin, NEW_ADMIN);
        assert!(mdtn::is_admin(NEW_ADMIN), ETEST_FAILED);
    }

    #[test]
    public fun test_grant_mint_role_success() {
        let admin = setup_test();
        mdtn::grant_mint_role(&admin, MINTER);
        
        // Test minting with granted role
        mdtn::mint(&account::create_account_for_test(MINTER), USER1, MINT_AMOUNT);
        let balance = primary_fungible_store::balance(USER1, mdtn::metadata());
        assert!(balance == MINT_AMOUNT, ETEST_FAILED);
    }

    #[test]
    #[expected_failure(abort_code = mdtn::EUNAUTHORIZED)]
    public fun test_mint_unauthorized() {
        let admin = setup_test();
        let unauthorized = account::create_account_for_test(USER1);
        mdtn::mint(&unauthorized, USER2, MINT_AMOUNT);
    }

    #[test]
    public fun test_grant_burn_role_success() {
        let admin = setup_test();
        // First mint some tokens
        mdtn::mint(&admin, USER1, MINT_AMOUNT);
        
        // Grant burn role
        mdtn::grant_burn_role(&admin, BURNER);
        
        // Test burning with granted role
        mdtn::burn(
            &account::create_account_for_test(BURNER),
            USER1,
            BURN_AMOUNT
        );
        
        let balance = primary_fungible_store::balance(USER1, mdtn::metadata());
        assert!(balance == MINT_AMOUNT - BURN_AMOUNT, ETEST_FAILED);
    }

    #[test]
    #[expected_failure(abort_code = mdtn::EUNAUTHORIZED)]
    public fun test_burn_unauthorized() {
        let admin = setup_test();
        // First mint some tokens
        mdtn::mint(&admin, USER1, MINT_AMOUNT);
        
        // Try to burn with unauthorized account
        let unauthorized = account::create_account_for_test(USER2);
        mdtn::burn(&unauthorized, USER1, BURN_AMOUNT);
    }

    #[test]
    public fun test_transfer_with_tax_success() {
        let admin = setup_test();
        // Mint initial tokens
        mdtn::mint(&admin, USER1, MINT_AMOUNT);
        
        // Transfer tokens
        mdtn::transfer(
            &account::create_account_for_test(USER1),
            USER2,
            TRANSFER_AMOUNT
        );
        
        // Calculate expected amounts after tax
        let tax = (TRANSFER_AMOUNT * 10) / 100; // 10% tax
        let expected_transfer = TRANSFER_AMOUNT - tax;
        
        // Check balances
        let balance_sender = primary_fungible_store::balance(USER1, mdtn::metadata());
        let balance_receiver = primary_fungible_store::balance(USER2, mdtn::metadata());
        let balance_treasury = primary_fungible_store::balance(@mdtn_addr, mdtn::metadata());
        
        assert!(balance_sender == MINT_AMOUNT - TRANSFER_AMOUNT, ETEST_FAILED);
        assert!(balance_receiver == expected_transfer, ETEST_FAILED);
        assert!(balance_treasury == tax, ETEST_FAILED);
    }

    #[test]
    public fun test_multiple_admin_operations() {
        let admin = setup_test();
        
        // Add new admin
        mdtn::add_admin(&admin, NEW_ADMIN);
        
        // New admin grants roles
        let new_admin_signer = account::create_account_for_test(NEW_ADMIN);
        mdtn::grant_mint_role(&new_admin_signer, MINTER);
        mdtn::grant_burn_role(&new_admin_signer, BURNER);
        
        // Test operations with granted roles
        mdtn::mint(&account::create_account_for_test(MINTER), USER1, MINT_AMOUNT);
        mdtn::burn(&account::create_account_for_test(BURNER), USER1, BURN_AMOUNT);
        
        let final_balance = primary_fungible_store::balance(USER1, mdtn::metadata());
        assert!(final_balance == MINT_AMOUNT - BURN_AMOUNT, ETEST_FAILED);
    }

    #[test]
    #[expected_failure(abort_code = mdtn::EROLE_EXISTS)]
    public fun test_duplicate_admin_add() {
        let admin = setup_test();
        mdtn::add_admin(&admin, NEW_ADMIN);
        mdtn::add_admin(&admin, NEW_ADMIN); // Should fail
    }

    #[test]
    #[expected_failure(abort_code = mdtn::EROLE_EXISTS)]
    public fun test_duplicate_mint_role() {
        let admin = setup_test();
        mdtn::grant_mint_role(&admin, MINTER);
        mdtn::grant_mint_role(&admin, MINTER); // Should fail
    }

    #[test]
    public fun test_admin_mint_burn_directly() {
        let admin = setup_test();
        
        // Admin should be able to mint and burn without additional roles
        mdtn::mint(&admin, USER1, MINT_AMOUNT);
        mdtn::burn(&admin, USER1, BURN_AMOUNT);
        
        let final_balance = primary_fungible_store::balance(USER1, mdtn::metadata());
        assert!(final_balance == MINT_AMOUNT - BURN_AMOUNT, ETEST_FAILED);
    }

    #[test]
    public fun test_register_account_success() {
        let admin = setup_test();
        let new_user = account::create_account_for_test(@0x1111);
        mdtn::register_account(&new_user);
        
        // Verify the account is registered by minting some tokens
        mdtn::mint(&admin, @0x1111, MINT_AMOUNT);
        let balance = primary_fungible_store::balance(@0x1111, mdtn::metadata());
        assert!(balance == MINT_AMOUNT, ETEST_FAILED);
    }
}