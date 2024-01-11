use starknet::testing;
use starknet::ContractAddress;

use integer::BoundedInt;
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use dojo::test_utils::{spawn_test_world};
use token::tests::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};

use token::tests::utils;

use token::components::token::erc20::erc20_metadata::{erc_20_metadata_model, ERC20MetadataModel,};
use token::components::token::erc20::erc20_metadata::erc20_metadata_component::{
    ERC20MetadataImpl, ERC20MetadataTotalSupplyImpl, InternalImpl as ERC20MetadataInternalImpl
};

use token::components::token::erc20::erc20_balance::{erc_20_balance_model, ERC20BalanceModel,};
use token::components::token::erc20::erc20_balance::erc20_balance_component::{
    ERC20BalanceImpl, InternalImpl as ERC20BalanceInternalImpl
};

use token::components::token::erc20::erc20_mintable::erc20_mintable_component::InternalImpl as ERC20MintableInternalImpl;
use token::components::token::erc20::erc20_burnable::erc20_burnable_component::InternalImpl as ERC20BurnableInternalImpl;

use token::components::token::erc20::erc20_wrapper::{erc_20_wrapper_model, ERC20WrapperModel};
use token::components::token::erc20::erc20_wrapper::erc20_wrapper_component::{ERC20WrapperImpl};

use token::components::tests::mocks::erc20::erc20_wrapper_mock::erc20_wrapper_mock;
use token::components::tests::mocks::erc20::erc20_wrapper_mock::{
    IERC20WrapperAbi, IERC20WrapperAbiDispatcher, IERC20WrapperAbiDispatcherTrait
};
use token::components::tests::mocks::erc20::erc20_wrapper_mock::erc20_wrapper_mock::{
    ERC20InitializerImpl
};

use token::components::tests::mocks::erc20::erc20_classic_mock::{
    erc20_classic_mock, IERC20, IERC20Dispatcher, IERC20DispatcherTrait
};


fn STATE() -> (IWorldDispatcher, IERC20Dispatcher, IERC20WrapperAbiDispatcher) {
    let world = spawn_test_world(
        array![
            erc_20_metadata_model::TEST_CLASS_HASH,
            erc_20_balance_model::TEST_CLASS_HASH,
            erc_20_wrapper_model::TEST_CLASS_HASH
        ]
    );

    // deploy classic erc20
    // name_: felt252,
    // symbol_: felt252,
    // decimals_: u8,
    // initial_supply: u256,
    // recipient: ContractAddress

    let constructor_calldata: Array<felt252> = array![
        'ERC20 Classic',
        'ERC20 C',
        DECIMALS.into(),
        SUPPLY.low.into(),
        SUPPLY.high.into(),
        OWNER().into()
    ];

    let (erc20_classic_address, _) = starknet::syscalls::deploy_syscall(
        erc20_classic_mock::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        constructor_calldata.span(),
        false
    )
        .unwrap();

    let erc20_classic_dispatcher = IERC20Dispatcher { contract_address: erc20_classic_address };

    // deploy wrapper contract
    let mut erc20_wrapper_dispatcher = IERC20WrapperAbiDispatcher {
        contract_address: world
            .deploy_contract('salt', erc20_wrapper_mock::TEST_CLASS_HASH.try_into().unwrap())
    };

    // setup auth
    world.grant_writer('ERC20AllowanceModel', erc20_wrapper_dispatcher.contract_address);
    world.grant_writer('ERC20BalanceModel', erc20_wrapper_dispatcher.contract_address);
    world.grant_writer('ERC20MetadataModel', erc20_wrapper_dispatcher.contract_address);
    world.grant_writer('ERC20WrapperModel', erc20_wrapper_dispatcher.contract_address);

    (world, erc20_classic_dispatcher, erc20_wrapper_dispatcher)
}


fn setup() -> (IERC20Dispatcher, IERC20WrapperAbiDispatcher) {
    let (world, erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = STATE();
    erc20_wrapper_dispatcher.initializer(erc20_classic_dispatcher.contract_address);
    (erc20_classic_dispatcher, erc20_wrapper_dispatcher)
}

//
// initializer 
//

#[test]
#[available_gas(25000000)]
fn test_erc20_wrapper_initializer() {
    let (world, erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = STATE();

    erc20_wrapper_dispatcher.initializer(erc20_classic_dispatcher.contract_address);
    assert(
        erc20_wrapper_dispatcher.underlying() == erc20_classic_dispatcher.contract_address,
        'should be erc20_classic'
    );
}

#[test]
#[available_gas(25000000)]
#[should_panic(expected: ('ERC20: invalid zero address', 'ENTRYPOINT_FAILED'))]
fn test_erc20_wrapper_initializer_with_zero() {
    let (world, erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = STATE();
    erc20_wrapper_dispatcher.initializer(ZERO());
}

#[test]
#[available_gas(25000000)]
fn test_erc20_wrapper_initial_state() {
    let (erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = setup();

    assert(erc20_classic_dispatcher.balance_of(OWNER()) == SUPPLY, 'should be SUPPLY');
    assert(erc20_wrapper_dispatcher.balance_of(OWNER()) == 0, 'should be 0');
}
//
//  wrapper
//

#[test]
#[available_gas(30000000)]
fn test_erc20_wrapper_can_deposit() {
    let (erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = setup();

    let balance_before = erc20_classic_dispatcher
        .balance_of(erc20_wrapper_dispatcher.contract_address);

    utils::impersonate(OWNER());
    erc20_classic_dispatcher.approve(erc20_wrapper_dispatcher.contract_address, VALUE);
    erc20_wrapper_dispatcher.deposit(VALUE);

    let balance_after = erc20_classic_dispatcher
        .balance_of(erc20_wrapper_dispatcher.contract_address);

    assert(
        erc20_classic_dispatcher.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq SUPPLY-VALUE'
    );
    assert(erc20_wrapper_dispatcher.balance_of(OWNER()) == VALUE, 'Should eq VALUE');
    assert(balance_after == balance_before + VALUE, 'Should eq balance_before+VALUE');
}


#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_erc20_wrapper_deposit_more_than_owned() {
    let (erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = setup();

    utils::impersonate(OWNER());
    erc20_classic_dispatcher.approve(erc20_wrapper_dispatcher.contract_address, SUPPLY + 1);
    erc20_wrapper_dispatcher.deposit(SUPPLY + 1);
}


#[test]
#[available_gas(30000000)]
fn test_erc20_wrapper_can_withdraw() {
    let (erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = setup();

    utils::impersonate(OWNER());
    erc20_classic_dispatcher.approve(erc20_wrapper_dispatcher.contract_address, VALUE);
    erc20_wrapper_dispatcher.deposit(VALUE);

    assert(
        erc20_classic_dispatcher.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq SUPPLY-VALUE'
    );
    assert(erc20_wrapper_dispatcher.balance_of(OWNER()) == VALUE, 'Should eq VALUE');

    let balance_before = erc20_classic_dispatcher
        .balance_of(erc20_wrapper_dispatcher.contract_address);

    erc20_wrapper_dispatcher.withdraw(VALUE);

    let balance_after = erc20_classic_dispatcher
        .balance_of(erc20_wrapper_dispatcher.contract_address);

    assert(erc20_classic_dispatcher.balance_of(OWNER()) == SUPPLY, 'Should eq SUPPLY');
    assert(erc20_wrapper_dispatcher.balance_of(OWNER()) == 0, 'Should eq 0');

    assert(balance_after == balance_before - VALUE, 'Should eq balance_before-VALUE');
}


#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('u256_sub Overflow', 'ENTRYPOINT_FAILED',))]
fn test_erc20_wrapper_withdraw_more_than_deposited() {
    let (erc20_classic_dispatcher, mut erc20_wrapper_dispatcher) = setup();

    utils::impersonate(OWNER());
    erc20_classic_dispatcher.approve(erc20_wrapper_dispatcher.contract_address, VALUE);
    erc20_wrapper_dispatcher.deposit(VALUE);

    erc20_wrapper_dispatcher.withdraw(VALUE + 1);
}
// todo more tests & test events


