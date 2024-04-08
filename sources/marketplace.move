#[allow(lint(self_transfer))]
module yield_farming::farm {
    use std::vector;
    use sui::transfer;
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use std::option::{Option, none, some};
    use sui::tx_context::{Self, TxContext};

    /* Error Constants */
    const ENotFarmOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EMaxFarmsReached: u64 = 2;
    const EFarmAlreadyClosed: u64 = 3;
    const EInsufficientStaked: u64 = 4;

    /* Structs */
    struct AdminCap has key, store {
        id: UID
    }

    struct FarmOwnerCap has key, store {
        id: UID,
        farm_id: ID
    }

    struct OwnerAddressVector has key, store {
        id: UID,
        addresses: vector<address>
    }

    struct Farm has key, store {
        id: UID,
        name: String,
        closed: bool,
        creator: address,
        staked_tokens: Balance<SUI>,
        reward_tokens: Balance<SUI>,
        rewards_distributed: u64,
        started_at: u64,
        closed_at: Option<u64>
    }

    struct Stake has key, store {
        id: UID,
        owner: address,
        farm: ID,
        amount: u64,
        staked_at: u64
    }

    /* Functions */
    fun init(ctx: &mut TxContext) {
        let admin = AdminCap {
            id: object::new(ctx)
        };

        let addresses = vector::empty<address>();
        let admin_address = tx_context::sender(ctx);

        let owner_address_vector = OwnerAddressVector {
            id: object::new(ctx),
            addresses,
        };

        transfer::share_object(owner_address_vector);
        transfer::transfer(admin, admin_address);
    }

    public entry fun create_farm(
        name: String,
        clock: &Clock,
        address_vector: &mut OwnerAddressVector,
        ctx: &mut TxContext
    ) {
        let farm_owner_address = tx_context::sender(ctx);
        assert!(!vector::contains<address>(&address_vector.addresses, &farm_owner_address), EMaxFarmsReached);

        let farm_uid = object::new(ctx);
        let farm_id = object::uid_to_inner(&farm_uid);

        let farm = Farm {
            id: farm_uid,
            name,
            closed: false,
            creator: farm_owner_address,
            staked_tokens: balance::zero(),
            reward_tokens: balance::zero(),
            rewards_distributed: 0,
            started_at: clock::timestamp_ms(clock),
            closed_at: none()
        };

        let farm_owner_id = object::new(ctx);

        let farm_owner = FarmOwnerCap {
            id: farm_owner_id,
            farm_id
        };

        vector::push_back<address>(&mut address_vector.addresses, farm_owner_address);

        transfer::share_object(farm);
        transfer::transfer(farm_owner, farm_owner_address);
    }

    public entry fun stake(
        amount: Coin<SUI>,
        farm: &mut Farm,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);

        let amount_staked = coin::value(&amount);
        let staker_address = tx_context::sender(ctx);

        let coin_balance = coin::into_balance(amount);
        balance::join(&mut farm.staked_tokens, coin_balance);

        let stake = Stake {
            id: object::new(ctx),
            owner: staker_address,
            farm: object::uid_to_inner(&farm.id),
            amount: amount_staked,
            staked_at: clock::timestamp_ms(clock)
        };

        transfer::share_object(stake);
    }

    public entry fun claim_rewards(
        farm: &mut Farm,
        stake: &mut Stake,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        assert!(stake.owner == tx_context::sender(ctx), ENotFarmOwner);

        let time_elapsed = clock::timestamp_ms(clock) - stake.staked_at;
        let rewards = (stake.amount * time_elapsed) / farm.started_at;
        assert!(balance::value(&farm.reward_tokens) >= rewards, EInsufficientBalance);

        balance::join(&mut stake.owner, coin::take(&mut farm.reward_tokens, rewards, ctx));
        farm.rewards_distributed += rewards;
    }

    public entry fun withdraw(
        amount: u64,
        farm: &mut Farm,
        stake: &mut Stake,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        assert!(stake.owner == tx_context::sender(ctx), ENotFarmOwner);
        assert!(stake.amount >= amount, EInsufficientStaked);

        let withdrawn = coin::take(&mut farm.staked_tokens, amount, ctx);
        stake.amount -= amount;

        transfer::public_transfer(withdrawn, tx_context::sender(ctx));

        if (stake.amount == 0) {
            object::delete(stake);
        }
    }

    public entry fun close_farm(
        _: &AdminCap,
        farm: &mut Farm,
        clock: &Clock
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        farm.closed = true;
        farm.closed_at = some(clock::timestamp_ms(clock));
    }

    public entry fun get_farm_details(farm: &Farm): (bool, u64, u64, u64) {
        (farm.closed, balance::value(&farm.staked_tokens), balance::value(&farm.reward_tokens), farm.rewards_distributed)
    }
}