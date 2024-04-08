module DefiYieldFarm::farm {
    use std::vector;
    use sui::transfer;
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use std::option::{Option, none, some};
    use sui::tx_context::{Self, TxContext, sender};

    const YEAR: u64 = 31556926;

    /* Error Constants */
    const ENotFarmOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EMaxFarmsReached: u64 = 2;
    const EFarmAlreadyClosed: u64 = 3;
    const EInsufficientStaked: u64 = 4;
    const EWrongFarm: u64 = 5;

    /* Structs */
    struct AdminCap has key {
        id: UID
    }

    struct FarmOwnerCap has key, store {
        id: UID,
        farm_id: ID
    }

    struct Farm has key, store {
        id: UID,
        closed: bool,
        creator: address,
        staked_tokens: u64,
        reward_tokens: Balance<SUI>,
        rewards_distributed: u64,
        started_at: u64,
        closed_at: Option<u64>
    }

    struct Stake has key, store {
        id: UID,
        farm_id: ID,
        stake: Balance<SUI>,
        reward_tokens: Balance<SUI>,
        staked_at: u64
    }

    /* Functions */
    fun init(ctx: &mut TxContext) {
        let admin = AdminCap {
            id: object::new(ctx)
        };
        transfer::transfer(admin, sender(ctx));
    }

    public fun new_stake(farm_id: ID, ctx: &mut TxContext) : Stake {
        let stake = Stake {
            id: object::new(ctx),
            farm_id: farm_id,
            stake: balance::zero(),
            reward_tokens: balance::zero(),
            staked_at: 0
        };
        stake
    }

    public entry fun create_farm(
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let farm_owner_address = sender(ctx);
        let farm_uid = object::new(ctx);
        let farm_id = object::uid_to_inner(&farm_uid);

        let farm = Farm {
            id: farm_uid,
            closed: false,
            creator: farm_owner_address,
            staked_tokens: 0,
            reward_tokens: balance::zero(),
            rewards_distributed: 0,
            started_at: clock::timestamp_ms(clock),
            closed_at: none()
        };

        let farm_owner = FarmOwnerCap {
            id: object::new(ctx),
            farm_id
        };
        transfer::share_object(farm);
        transfer::transfer(farm_owner, farm_owner_address);
    }

    public fun add_liquity(cap: &FarmOwnerCap, farm: &mut Farm, coin: Coin<SUI>) {
        assert!(object::id(farm) == cap.farm_id, EWrongFarm);
        let balance_ = coin::into_balance(coin);
        balance::join(&mut farm.reward_tokens, balance_);
    }

    public entry fun stake(
        farm: &mut Farm,
        stake: &mut Stake,
        clock: &Clock,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        assert!(object::id(farm) == stake.farm_id, EWrongFarm);

        let amount_staked = coin::value(&amount);
        farm.staked_tokens = farm.staked_tokens + amount_staked;

        let coin_balance = coin::into_balance(amount);
        balance::join(&mut stake.stake, coin_balance);
    }

    public entry fun claim_rewards(
        farm: &mut Farm,
        stake: &mut Stake,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        assert!(object::id(farm) == stake.farm_id, EWrongFarm);

        let time_elapsed = clock::timestamp_ms(clock) - stake.staked_at;
        let stake_amount = balance::value(&stake.stake);
        let rewards = (stake_amount) * (time_elapsed / YEAR);
        assert!(balance::value(&farm.reward_tokens) >= rewards, EInsufficientBalance);

        let coin_ = coin::take(&mut farm.reward_tokens, rewards, ctx);
        let balance_ = coin::into_balance(coin_);
        let amount = balance::join(&mut stake.reward_tokens, balance_);
        farm.rewards_distributed =  farm.rewards_distributed + rewards;
    }

    public entry fun withdraw(
        farm: &mut Farm,
        stake: &mut Stake,
        clock: &Clock,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        assert!(object::id(farm) == stake.farm_id, EWrongFarm);
        assert!(amount <= balance::value(&stake.stake), EInsufficientStaked);

        let witdraw = coin::take(&mut stake.stake, amount, ctx);
        farm.staked_tokens = farm.staked_tokens -  amount;

        transfer::public_transfer(witdraw, tx_context::sender(ctx));
    }

    public entry fun close_farm(
        _: &FarmOwnerCap,
        farm: &mut Farm,
        clock: &Clock
    ) {
        assert!(!farm.closed, EFarmAlreadyClosed);
        farm.closed = true;
        farm.closed_at = some(clock::timestamp_ms(clock));
    }
}
