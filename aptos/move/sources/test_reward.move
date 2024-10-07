#[test_only]
module reward_addr::tests_reward {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use reward_addr::reward;
    use mdtn_addr::mdtn;
    use std::debug;

    // Test constants
    const REWARD_AMOUNT: u64 = 1000000;
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
    public entry fun test_initialize_reward(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);

        // Initialize MDTN token
        mdtn::init_for_test(&admin);

        // Initialize reward
        reward::init_admin(&admin);

        // Verify admin is set correctly
        assert!(
            reward::get_admin_address(signer::address_of(&admin))
                == signer::address_of(&admin),
            0
        );
    }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_setup_reward_success(aptos_framework: &signer) {
        let (admin, _, _) = create_test_accounts(aptos_framework);

        mdtn::init_for_test(&admin);
        reward::init_admin(&admin);

        reward::setup_reward(
            &admin,
            signer::address_of(&admin),
            REWARD_AMOUNT,
            END_TIME,
            NFT_ID
        );

        let (amount, end_time, nft_id, is_active) =
            reward::get_reward_info(NFT_ID, signer::address_of(&admin));
        assert!(amount == REWARD_AMOUNT, 0);
        assert!(end_time == END_TIME, 0);
        assert!(nft_id == NFT_ID, 0);
        assert!(!is_active, 0);
    }

    // #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = ENOT_ADMIN)]
    // public entry fun test_setup_reward_not_admin(aptos_framework: &signer) {
    //     let (admin, user, _) = create_test_accounts(aptos_framework);

    //     mdtn::init_for_test(&admin);
    //     reward::init_admin(&admin);

    //     // Try to setup reward with non-admin account
    //     reward::setup_reward(&user, signer::address_of(&admin), REWARD_AMOUNT, END_TIME, NFT_ID);
    // }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_set_addresses_success(aptos_framework: &signer) {
        let (admin, _, recipients) = create_test_accounts(aptos_framework);

        mdtn::init_for_test(&admin);
        reward::init_admin(&admin);
        reward::setup_reward(
            &admin,
            signer::address_of(&admin),
            REWARD_AMOUNT,
            END_TIME,
            NFT_ID
        );

        timestamp::fast_forward_seconds(END_TIME + 1);

        reward::set_addresses(&admin, signer::address_of(&admin), NFT_ID, recipients);

        // Verify addresses are set (indirectly, since we can't access the addresses directly)
        let (_, _, _, is_active) =
            reward::get_reward_info(NFT_ID, signer::address_of(&admin));
        assert!(!is_active, 0); // Should still be inactive
    }

    // #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = EDROP_NOT_STARTED)]
    // public entry fun test_set_addresses_too_early(aptos_framework: &signer) {
    //     let (admin, _, recipients) = create_test_accounts(aptos_framework);

    //     mdtn::init_for_test(&admin);
    //     reward::init_admin(&admin);
    //     reward::setup_reward(&admin, signer::address_of(&admin), REWARD_AMOUNT, END_TIME, NFT_ID);

    //     // Try to set addresses before end_time
    //     reward::set_addresses(&admin, signer::address_of(&admin), NFT_ID, recipients);
    // }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_execute_reward_success(aptos_framework: &signer) {
        let (admin, _, recipients) = create_test_accounts(aptos_framework);

        mdtn::init_for_test(&admin);
        reward::init_admin(&admin);
        reward::setup_reward(
            &admin,
            signer::address_of(&admin),
            REWARD_AMOUNT,
            END_TIME,
            NFT_ID
        );

        timestamp::fast_forward_seconds(END_TIME + 1);
        reward::set_addresses(&admin, signer::address_of(&admin), NFT_ID, recipients);

        // // Execute reward
        reward::execute_reward(&admin, signer::address_of(&admin), NFT_ID);

        // Verify reward is marked as active
        let (_, _, _, is_active) =
            reward::get_reward_info(NFT_ID, signer::address_of(&admin));
        assert!(is_active, 0);
    }

    // #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = 1091)]
    // public entry fun test_execute_reward_addresses_not_set(aptos_framework: &signer) {
    //     let (admin, _, _) = create_test_accounts(aptos_framework);

    //     mdtn::init_for_test(&admin);
    //     reward::init_admin(&admin);
    //     reward::setup_reward(&admin, signer::address_of(&admin), REWARD_AMOUNT, END_TIME, NFT_ID);

    //     timestamp::fast_forward_seconds(END_TIME + 1);

    //     // Try to execute reward without setting addresses
    //     reward::execute_reward(&admin, signer::address_of(&admin), NFT_ID);
    // }

    // #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = ENOT_FOUND)]
    // public entry fun test_get_reward_info_not_found(aptos_framework: &signer) {
    //     let (admin, _, _) = create_test_accounts(aptos_framework);

    //     mdtn::init_for_test(&admin);
    //     reward::init_admin(&admin);

    //     // Try to get info for non-existent reward
    //     reward::get_reward_info(@0x999, signer::address_of(&admin));
    // }

    #[test(aptos_framework = @aptos_framework)]
    public entry fun test_change_admin_success(aptos_framework: &signer) {
        let (admin, user, _) = create_test_accounts(aptos_framework);

        reward::init_admin(&admin);

        // Change admin
        reward::change_admin(&admin, signer::address_of(&user));

        // Verify new admin
        assert!(
            reward::get_admin_address(signer::address_of(&admin))
                == signer::address_of(&user),
            0
        );
    }

    // #[test(aptos_framework = @aptos_framework)]
    // #[expected_failure(abort_code = 4008)]
    // public entry fun test_change_admin_not_admin(aptos_framework: &signer) {
    //     let (admin, user, _) = create_test_accounts(aptos_framework);

    //     reward::init_for_test(&admin);
    //     // Try to change admin with non-admin account
    //     reward::change_admin(&user, signer::address_of(&admin))
    // }
}
