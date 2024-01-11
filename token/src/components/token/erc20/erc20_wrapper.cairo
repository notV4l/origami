use starknet::ContractAddress;

///
/// Model
///

#[derive(Model, Copy, Drop, Serde)]
struct ERC20WrapperModel {
    #[key]
    token: ContractAddress,
    underlying: ContractAddress,
}

///
/// Interface
///

#[starknet::interface]
trait IERC20Wrapper<TState> {
    fn deposit(ref self: TState, amount: u256);
    fn withdraw(ref self: TState, amount: u256);
    fn underlying(self: @TState) -> ContractAddress;
}

// only supports snake_case
#[starknet::interface]
trait IERC20Transfer<TState> {
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
}

///
/// ERC20Wrapper Component, should be non upgradeable!
///
#[starknet::component]
mod erc20_wrapper_component {
    use super::IERC20Wrapper;
    use super::{IERC20Transfer, IERC20TransferDispatcher, IERC20TransferDispatcherTrait};
    use super::ERC20WrapperModel;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use starknet::get_caller_address;
    use dojo::world::{
        IWorldProvider, IWorldProviderDispatcher, IWorldDispatcher, IWorldDispatcherTrait
    };

    use token::components::token::erc20::erc20_balance::erc20_balance_component as erc20_balance_comp;
    use token::components::token::erc20::erc20_metadata::erc20_metadata_component as erc20_metadata_comp;
    use token::components::token::erc20::erc20_mintable::erc20_mintable_component as erc20_mintable_comp;
    use token::components::token::erc20::erc20_burnable::erc20_burnable_component as erc20_burnable_comp;

    use erc20_balance_comp::InternalImpl as ERC20BalanceInternal;
    use erc20_metadata_comp::InternalImpl as ERC20MetadataInternal;
    use erc20_mintable_comp::InternalImpl as ERC20MintableInternal;
    use erc20_burnable_comp::InternalImpl as ERC20BurnableInternal;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Copy, Drop, Serde, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdrawal: Withdrawal,
    }

    #[derive(Copy, Drop, Serde, starknet::Event)]
    struct Deposit {
        address: ContractAddress,
        amount: u256
    }

    #[derive(Copy, Drop, Serde, starknet::Event)]
    struct Withdrawal {
        address: ContractAddress,
        amount: u256
    }

    mod Errors {
        const INVALID_ZERO_ADDRESS: felt252 = 'ERC20: invalid zero address';
    }

    #[embeddable_as(ERC20WrapperImpl)]
    impl ERC20Wrapper<
        TContractState,
        +HasComponent<TContractState>,
        +IWorldProvider<TContractState>,
        impl ERC20Balance: erc20_balance_comp::HasComponent<TContractState>,
        impl ERC20Metadata: erc20_metadata_comp::HasComponent<TContractState>,
        impl ERC20Mintable: erc20_mintable_comp::HasComponent<TContractState>,
        impl ERC20Burnable: erc20_burnable_comp::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC20Wrapper<ComponentState<TContractState>> {
        /// user must approve first
        fn deposit(ref self: ComponentState<TContractState>, amount: u256) {
            let caller = get_caller_address();
            let token_dispatcher = self.get_underlying_dispatcher();

            // reverts if can't transfer from caller
            token_dispatcher.transfer_from(caller, get_contract_address(), amount);

            let mut erc20_mintable = get_dep_component_mut!(ref self, ERC20Mintable);
            erc20_mintable.mint(caller, amount);

            self.emit(Deposit { address: caller, amount, });
        }

        fn withdraw(ref self: ComponentState<TContractState>, amount: u256) {
            let caller = get_caller_address();
            let token_dispatcher = self.get_underlying_dispatcher();

            // reverts if can't burn from caller
            let mut erc20_burnable = get_dep_component_mut!(ref self, ERC20Burnable);
            erc20_burnable.burn(caller, amount);

            token_dispatcher.transfer(caller, amount);

            self.emit(Withdrawal { address: caller, amount, });
        }

        fn underlying(self: @ComponentState<TContractState>,) -> ContractAddress {
            self.get_model().underlying
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +IWorldProvider<TContractState>,
        impl ERC20Balance: erc20_balance_comp::HasComponent<TContractState>,
        impl ERC20Metadata: erc20_metadata_comp::HasComponent<TContractState>,
        impl ERC20Mintable: erc20_mintable_comp::HasComponent<TContractState>,
        impl ERC20Burnable: erc20_burnable_comp::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, underlying: ContractAddress) {
            assert(underlying.is_non_zero(), Errors::INVALID_ZERO_ADDRESS);

            set!(
                self.get_contract().world(),
                ERC20WrapperModel { token: get_contract_address(), underlying }
            )
        }

        fn get_model(self: @ComponentState<TContractState>) -> ERC20WrapperModel {
            get!(self.get_contract().world(), get_contract_address(), (ERC20WrapperModel))
        }

        fn get_underlying_dispatcher(
            self: @ComponentState<TContractState>
        ) -> IERC20TransferDispatcher {
            IERC20TransferDispatcher { contract_address: self.get_model().underlying }
        }

        fn emit_event<S, +traits::Into<S, Event>, +Drop<S>, +Clone<S>>(
            ref self: ComponentState<TContractState>, event: S
        ) {
            self.emit(event.clone());
            emit!(self.get_contract().world(), event);
        }
    }
}
