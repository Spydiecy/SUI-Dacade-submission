#[test_only]
module DefiYieldFarm::test_farm {
    use sui::test_scenario::{Self as ts, next_tx,Scenario};
    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::sui::SUI;
    use sui::tx_context::{TxContext, sender};
    use sui::clock::{Self, Clock};
    use sui::balance:: {Self, Balance};
    use sui::test_utils::{assert_eq};
    use sui::object::{Self};
    use sui::transfer;
    use std::vector;
    use std::string::{Self,String};
    use std::debug::{print};

    use DefiYieldFarm::farm::{Self, AdminCap, Farm, FarmOwnerCap, Stake, FarmId, init_for_testing};

  
 //*****************************************************************************************************************************************// 

    #[test]
    public fun test1() {

    let owner: address = @0xA;
    let alice: address = @0xB;
    let bob: address = @0xC;


    let scenario_test = ts::begin(owner);
    let scenario = &mut scenario_test;

    next_tx(scenario, owner);
    {
     init_for_testing(ts::ctx(scenario));
    };
    // alice creates farm 
    next_tx(scenario, alice); 
    {
        let time = clock::create_for_testing(ts::ctx(scenario));
        let farm_id_ = ts::take_shared<FarmId>(scenario);

        farm::create_farm(&mut farm_id_,&time, ts::ctx(scenario));

        clock::share_for_testing(time); 
        ts::return_shared(farm_id_);

    };
    // alice deposit liquity to farm object 
     next_tx(scenario, alice); 
    {
        let cap = ts::take_from_sender<FarmOwnerCap>(scenario);
        let farm = ts::take_shared<Farm>(scenario);
        let deposit = mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));

        farm::add_liquity(&cap, &mut farm, deposit);

        ts::return_to_sender(scenario, cap);
        ts::return_shared(farm);
    };
    // bob creates Stake object 
    next_tx(scenario, bob);
    {
        let farm_id_ = ts::take_shared<FarmId>(scenario);
        let farm_id = farm::get_farm_id(&farm_id_);
        let stake = farm::new_stake(farm_id, ts::ctx(scenario));
        transfer::public_transfer(stake, bob);

        ts::return_shared(farm_id_);
    };
    // stake 100 SUI
    next_tx(scenario, bob);
    {
        let farm = ts::take_shared<Farm>(scenario);
        let stake = ts::take_from_sender<Stake>(scenario); 
        let time = ts::take_shared<Clock>(scenario);
        let deposit = mint_for_testing<SUI>(100_000_000_000, ts::ctx(scenario));

        farm::stake(
            &mut farm,
            &mut stake,
            &time,
            deposit,
            ts::ctx(scenario)
        );

        ts::return_shared(farm);
        ts::return_shared(time);
        ts::return_to_sender(scenario, stake);
    };
    // claim rewards 
    next_tx(scenario, bob);
    {
        let farm = ts::take_shared<Farm>(scenario);
        let stake = ts::take_from_sender<Stake>(scenario); 
        let time = ts::take_shared<Clock>(scenario);
         // increase approx 1 year. 
        clock::increment_for_testing(&mut time, (86400 * 31 * 12));

        farm::claim_rewards(
            &mut farm,
            &mut stake,
            &time,
            ts::ctx(scenario)
        );
        
        ts::return_shared(farm);
        ts::return_shared(time);
        ts::return_to_sender(scenario, stake);
    };
    // withdraw rewards
    next_tx(scenario, bob);
    {
        let stake = ts::take_from_sender<Stake>(scenario); 

        farm::withdraw_rewards(&mut stake, ts::ctx(scenario));

        ts::return_to_sender(scenario, stake);
    };

    next_tx(scenario, bob);
    {
        let bob_balance = ts::take_from_sender<Coin<SUI>>(scenario);
        assert_eq(coin::value(&bob_balance), 2_037_004_491);
        ts::return_to_sender(scenario, bob_balance);
    };

    // withdraw 100 SUI BACK
    next_tx(scenario, bob);
    {
        let farm = ts::take_shared<Farm>(scenario);
        let stake = ts::take_from_sender<Stake>(scenario); 
        let time = ts::take_shared<Clock>(scenario);
        let amount = 100_000_000_000;

        farm::withdraw(
            &mut farm,
            &mut stake,
            &time,
            amount,
            ts::ctx(scenario)
        );

        ts::return_shared(farm);
        ts::return_shared(time);
        ts::return_to_sender(scenario, stake);
    };

    next_tx(scenario, bob);
    {
        let bob_balance = ts::take_from_sender<Coin<SUI>>(scenario);
        assert_eq(coin::value(&bob_balance), 100_000_000_000);
        ts::return_to_sender(scenario, bob_balance);
    };















    ts::end(scenario_test);

}













}