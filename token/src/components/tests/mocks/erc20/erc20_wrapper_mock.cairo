use starknet::{ContractAddress, ClassHash};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

#[starknet::interface]
trait IERC20WrapperAbi<TState> {
    // IWorldProvider
    fn world(self: @TState,) -> IWorldDispatcher;

    // IUpgradeable
    fn upgrade(ref self: TState, new_class_hash: ClassHash);

    // IERC20Metadata
    fn decimals(self: @TState,) -> u8;
    fn name(self: @TState,) -> felt252;
    fn symbol(self: @TState,) -> felt252;

    // IERC20MetadataTotalSupply
    fn total_supply(self: @TState,) -> u256;

    // IERC20MetadataTotalSupplyCamel
    fn totalSupply(self: @TState,) -> u256;

    // IERC20Balance
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    // IERC20BalanceCamel
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    // IERC20Allowance
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // IERC20SafeAllowance
    fn decrease_allowance(
        ref self: TState, spender: ContractAddress, subtracted_value: u256
    ) -> bool;
    fn increase_allowance(ref self: TState, spender: ContractAddress, added_value: u256) -> bool;

    // IERC20SafeAllowanceCamel
    fn decreaseAllowance(ref self: TState, spender: ContractAddress, subtractedValue: u256) -> bool;
    fn increaseAllowance(ref self: TState, spender: ContractAddress, addedValue: u256) -> bool;

    // IERC20Wrapper
    fn deposit(ref self: TState, amount: u256);
    fn withdraw(ref self: TState, amount: u256);
    fn underlying(self: @TState,) -> ContractAddress;

    fn initializer(ref self: TState, underlying: ContractAddress);
    fn dojo_resource(self: @TState,) -> felt252;
}

#[starknet::interface]
trait IERC20MetadataAbi<TState> {
    fn decimals(self: @TState,) -> u8;
    fn name(self: @TState,) -> felt252;
    fn symbol(self: @TState,) -> felt252;
}


#[dojo::contract]
mod erc20_wrapper_mock {
    use super::{IERC20MetadataAbi, IERC20MetadataAbiDispatcher, IERC20MetadataAbiDispatcherTrait};
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};

    use token::components::security::initializable::initializable_component;

    use token::components::token::erc20::erc20_allowance::erc20_allowance_component;
    use token::components::token::erc20::erc20_balance::erc20_balance_component;
    use token::components::token::erc20::erc20_metadata::erc20_metadata_component;
    use token::components::token::erc20::erc20_mintable::erc20_mintable_component;
    use token::components::token::erc20::erc20_burnable::erc20_burnable_component;
    use token::components::token::erc20::erc20_wrapper::erc20_wrapper_component;

    component!(path: initializable_component, storage: initializable, event: InitializableEvent);

    component!(
        path: erc20_allowance_component, storage: erc20_allowance, event: ERC20AllowanceEvent
    );
    component!(path: erc20_balance_component, storage: erc20_balance, event: ERC20BalanceEvent);
    component!(path: erc20_metadata_component, storage: erc20_metadata, event: ERC20MetadataEvent);
    component!(path: erc20_mintable_component, storage: erc20_mintable, event: ERC20MintableEvent);
    component!(path: erc20_burnable_component, storage: erc20_burnable, event: ERC20BurnableEvent);
    component!(path: erc20_wrapper_component, storage: erc20_wrapper, event: ERC20WrapperEvent);

    impl InitializableInternalImpl = initializable_component::InternalImpl<ContractState>;

    impl ERC20AllowanceInternalImpl = erc20_allowance_component::InternalImpl<ContractState>;
    impl ERC20BalanceInternalImpl = erc20_balance_component::InternalImpl<ContractState>;
    impl ERC20MetadataInternalImpl = erc20_metadata_component::InternalImpl<ContractState>;
    impl ERC20MintableInternalImpl = erc20_mintable_component::InternalImpl<ContractState>;
    impl ERC20BurnableInternalImpl = erc20_burnable_component::InternalImpl<ContractState>;
    impl ERC20WrapperInternalImpl = erc20_wrapper_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        initializable: initializable_component::Storage,
        #[substorage(v0)]
        erc20_allowance: erc20_allowance_component::Storage,
        #[substorage(v0)]
        erc20_balance: erc20_balance_component::Storage,
        #[substorage(v0)]
        erc20_metadata: erc20_metadata_component::Storage,
        #[substorage(v0)]
        erc20_mintable: erc20_mintable_component::Storage,
        #[substorage(v0)]
        erc20_burnable: erc20_burnable_component::Storage,
        #[substorage(v0)]
        erc20_wrapper: erc20_wrapper_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InitializableEvent: initializable_component::Event,
        ERC20AllowanceEvent: erc20_allowance_component::Event,
        ERC20BalanceEvent: erc20_balance_component::Event,
        ERC20MetadataEvent: erc20_metadata_component::Event,
        ERC20MintableEvent: erc20_mintable_component::Event,
        ERC20BurnableEvent: erc20_burnable_component::Event,
        ERC20WrapperEvent: erc20_wrapper_component::Event,
    }

    mod Errors {
        const CALLER_IS_NOT_OWNER: felt252 = 'ERC20: caller is not owner';
    }

    impl InitializableImpl = initializable_component::InitializableImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20AllowanceImpl =
        erc20_allowance_component::ERC20AllowanceImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20BalanceImpl =
        erc20_balance_component::ERC20BalanceImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20MetadataImpl =
        erc20_metadata_component::ERC20MetadataImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20WrapperImpl =
        erc20_wrapper_component::ERC20WrapperImpl<ContractState>;

    //
    // Initializer
    //

    #[external(v0)]
    #[generate_trait]
    impl ERC20InitializerImpl of ERC20InitializerTrait {
        fn initializer(ref self: ContractState, underlying: ContractAddress,) {
            assert(
                self.world().is_owner(get_caller_address(), get_contract_address().into()),
                Errors::CALLER_IS_NOT_OWNER
            );

            // reverts if underlying == zero
            self.erc20_wrapper.initialize(underlying);

            let underlying_metadata_dispatcher = IERC20MetadataAbiDispatcher {
                contract_address: underlying
            };

            let name = ''; // fak how to 'Dojo Wrapped {name}'
            let symbol = ''; // fak how to 'dw{symbol}'
            let decimals = underlying_metadata_dispatcher.decimals();

            self.erc20_metadata.initialize(name, symbol, decimals);

            self.initializable.initialize();
        }
    }
}
