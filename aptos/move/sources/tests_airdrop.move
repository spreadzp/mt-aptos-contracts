#[test_only]
module airdrop_addr::tests_airdrop {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;
    use airdrop_addr::airdrop;
    use mdtn_addr::mdtn;

    // Test constants
    const AIRDROP_AMOUNT: u64 = 1000000;
    const END_TIME: u64 = 1000000000;
    const NFT_ID: address = @0x123;

    // Error codes
    const ENOT_ADMIN: u64 = 1;
    const EDROP_NOT_STARTED: u64 = 3;
    const EDROP_ALREADY_STARTED: u64 = 4;
    const ENOT_FOUND: u64 = 5;

    // Helper function to create and fund test accounts
    fun create_test_accounts(aptos_framework: &signer): (signer, signer, vector<address>) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        let admin = account::create_account_for_test(@0x1); // Use a valid address
        let user = account::create_account_for_test(@0x2); // Use a valid address
        
        let recipients = vector::empty<address>();
        vector::push_back(&mut recipients, signer::address_of(&user));
        vector::push_back(&mut recipients, @0x456);
        vector::push_back(&mut recipients, @0x789);

        (admin, user, recipients)
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_initialize_airdrop(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);
        
        // Initialize MDTN token
        mdtn::init_for_test(&admin);
        
        // Initialize airdrop
        airdrop::init_for_test(&admin);
        
        // Verify admin is set correctly
        assert!(airdrop::get_admin_address(signer::address_of(&admin)) == signer::address_of(&admin), 0);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_setup_airdrop_success(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        
        airdrop::setup_airdrop(&admin, AIRDROP_AMOUNT, END_TIME, NFT_ID);
        
        let (amount, end_time, nft_id, is_active) = airdrop::get_airdrop_info(NFT_ID, signer::address_of(&admin));
        assert!(amount == AIRDROP_AMOUNT, 0);
        assert!(end_time == END_TIME, 0);
        assert!(nft_id == NFT_ID, 0);
        assert!(!is_active, 0);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ADMIN)]
    public entry fun test_setup_airdrop_not_admin(aptos_framework: &signer) {
        let (admin, user, _) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        
        // Try to setup airdrop with non-admin account
        airdrop::setup_airdrop(&user, AIRDROP_AMOUNT, END_TIME, NFT_ID);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_set_addresses_success(aptos_framework: &signer) {
        let (admin, _, recipients) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        airdrop::setup_airdrop(&admin, AIRDROP_AMOUNT, END_TIME, NFT_ID);
        
        timestamp::fast_forward_seconds(END_TIME + 1);
        
        airdrop::set_addresses(&admin, NFT_ID, recipients);
        
        // Verify addresses are set (indirectly, since we can't access the addresses directly)
        let (_, _, _, is_active) = airdrop::get_airdrop_info(NFT_ID, signer::address_of(&admin));
        assert!(!is_active, 0); // Should still be inactive
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = EDROP_NOT_STARTED)]
    public entry fun test_set_addresses_too_early(aptos_framework: &signer) {
        let (admin, _, recipients) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        airdrop::setup_airdrop(&admin, AIRDROP_AMOUNT, END_TIME, NFT_ID);
        
        // Try to set addresses before end_time
        airdrop::set_addresses(&admin, NFT_ID, recipients);
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_execute_airdrop_success(aptos_framework: &signer) {
        let (admin, _, recipients) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        airdrop::setup_airdrop(&admin, AIRDROP_AMOUNT, END_TIME, NFT_ID);
        
        timestamp::fast_forward_seconds(END_TIME + 1);
        airdrop::set_addresses(&admin, NFT_ID, recipients);
        
        // Execute airdrop
        airdrop::execute_airdrop(&admin, NFT_ID);
        
        // Verify airdrop is marked as active
        let (_, _, _, is_active) = airdrop::get_airdrop_info(NFT_ID, signer::address_of(&admin));
        assert!(is_active, 0);
        let asset = mdtn::metadata();
        // Verify token distribution (assuming 3 recipients)
        let expected_amount = AIRDROP_AMOUNT / 3;
        let user = account::create_account_for_test(@0x2);
        let user_balance = primary_fungible_store::balance(signer::address_of(&user), asset);
        let aaron_balance = primary_fungible_store::balance(@0x456, asset);
        let kc_balance = primary_fungible_store::balance(@0x789, asset);
        assert!(user_balance == expected_amount, 0);
        assert!(aaron_balance == expected_amount, 0);
        assert!(user_balance == expected_amount, 0);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = EDROP_NOT_STARTED)]
    public entry fun test_execute_airdrop_addresses_not_set(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        airdrop::setup_airdrop(&admin, AIRDROP_AMOUNT, END_TIME, NFT_ID);
        
        timestamp::fast_forward_seconds(END_TIME + 1);
        
        // Try to execute airdrop without setting addresses
        airdrop::execute_airdrop(&admin, NFT_ID);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_FOUND)]
    public entry fun test_get_airdrop_info_not_found(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);
        
        mdtn::init_for_test(&admin);
        airdrop::init_for_test(&admin);
        
        // Try to get info for non-existent airdrop
        airdrop::get_airdrop_info(@0x999, signer::address_of(&admin));
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_change_admin_success(aptos_framework: &signer) {
        let (admin, user, _) = create_test_accounts(aptos_framework);
        
        airdrop::init_for_test(&admin);
        
        // Change admin
        airdrop::change_admin(&admin, signer::address_of(&user));
        
        // Verify new admin
        assert!(airdrop::get_admin_address(signer::address_of(&admin)) == signer::address_of(&user), 0);
    }

    #[test(aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = ENOT_ADMIN)]
    public entry fun test_change_admin_not_admin(aptos_framework: &signer) {
        let (admin, user, _) = create_test_accounts(aptos_framework);
        
        airdrop::init_for_test(&admin);
        
        // Try to change admin with non-admin account
        airdrop::change_admin(&user, signer::address_of(&admin));
    }
}