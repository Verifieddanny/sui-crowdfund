module crowdfund::crowdfund;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

// Error constants
const EINVALID: u64 = 0;

// Struct to track contributors
public struct Contributor has copy, drop, store {
    wallet_address: address,
    amount: u64,
    timestamp: u64,
}
// Struct to manage all crowdfunds
public struct CrowdfundManager has key {
    id: UID,
    crowdfunds: vector<address>, // Store all crowdfund addresses
}

// Main crowdfund struct (You can switch it up to what you want)
public struct Crowdfund has key {
    id: UID,
    name: String,
    description: String,
    creator: address,
    crowdfund_type: u8, // 0 for grant, 1 for ICO
    target_amount: u64,
    current_amount: u64,
    deadline: u64,
    contributors: vector<Contributor>,
    funds: Balance<SUI>,
    is_active: bool,
    is_successful: bool,
}

// Initialize the crowdfunding platform
fun init(ctx: &mut TxContext) {
    let manager = CrowdfundManager {
        id: object::new(ctx),
        crowdfunds: vector::empty<address>(),
    };
    transfer::share_object(manager)
}

public fun create_crowdfund(
    manager: &mut CrowdfundManager,
    name: String,
    description: String,
    crowdfund_type: u8,
    target_amount: u64,
    deadline: u64,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);

    let crowdfund_property = Crowdfund {
        id: object::new(ctx),
        name,
        description,
        creator: sender,
        crowdfund_type,
        target_amount,
        current_amount: 0,
        deadline,
        contributors: vector::empty<Contributor>(),
        funds: balance::zero(),
        is_active: true,
        is_successful: false,
    };

    let property_id = object::id_address(&crowdfund_property);
    vector::push_back(&mut manager.crowdfunds, property_id);

    transfer::share_object(crowdfund_property);
}

public fun contribute(
    crowdfund: &mut Crowdfund,
    payment: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    let amount = coin::value(&payment);

    assert!(crowdfund.is_active, EINVALID);
    let contributor = Contributor {
        wallet_address: sender,
        amount,
        timestamp: clock.timestamp_ms(),
    };

    vector::push_back(&mut crowdfund.contributors, contributor);

    let payment_balance = coin::into_balance(payment);
    crowdfund.current_amount = crowdfund.current_amount + amount;
    balance::join(&mut crowdfund.funds, payment_balance);
}

public fun withdraw(crowdfund: &mut Crowdfund, clock: &Clock, ctx: &mut TxContext) {
    assert!(clock.timestamp_ms() > crowdfund.deadline, EINVALID);
    assert!(crowdfund.is_active, EINVALID);

    let available_funds = balance::value(&crowdfund.funds);

    if (available_funds > 0) {
        let withdraw_coin = coin::from_balance(
            balance::split(&mut crowdfund.funds, available_funds),
            ctx,
        );

        crowdfund.is_active = false;

        transfer::public_transfer(withdraw_coin, crowdfund.creator)
    }
}

public fun get_crowdfund_info(
    crowdfund: &Crowdfund,
): (
    String, // name
    String, // description
    address, // creator
    u8, //Crowdfund Type
    u64, // target amount
    u64, // current amount
    u64, // deadline
    bool, // is active
    bool, // is successful
) {
    (
        crowdfund.name,
        crowdfund.description,
        crowdfund.creator,
        crowdfund.crowdfund_type,
        crowdfund.target_amount,
        crowdfund.current_amount,
        crowdfund.deadline,
        crowdfund.is_active,
        crowdfund.is_successful,
    )
}
