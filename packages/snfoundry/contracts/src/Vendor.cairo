use starknet::ContractAddress;
#[starknet::interface]
pub trait IVendor<T> {
    fn buy_tokens(ref self: T, eth_amount_wei: u256);
    fn withdraw(ref self: T);
    fn sell_tokens(ref self: T, amount_tokens: u256);
    fn tokens_per_eth(self: @T) -> u256;
    fn your_token(self: @T) -> ContractAddress;
    fn eth_token(self: @T) -> ContractAddress;
}

#[starknet::contract]
mod Vendor {
    use OwnableComponent::InternalTrait;
    use contracts::YourToken::{IYourTokenDispatcher, IYourTokenDispatcherTrait};
    use core::traits::TryInto;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_access::ownable::interface::IOwnable;
    use openzeppelin_token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{get_caller_address, get_contract_address};
    use super::{ContractAddress, IVendor};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ToDo Checkpoint 2: Define const TokensPerEth
    const TokensPerEth: u256 = 100;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        eth_token: IERC20CamelDispatcher,
        your_token: IYourTokenDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        BuyTokens: BuyTokens,
        SellTokens: SellTokens,
    }

    #[derive(Drop, starknet::Event)]
    struct BuyTokens {
        buyer: ContractAddress,
        eth_amount: u256,
        tokens_amount: u256,
    }

    //  ToDo Checkpoint 3: Define the event SellTokens
    #[derive(Drop, starknet::Event)]
    struct SellTokens {
        seller: ContractAddress,
        tokens_amount: u256,
        eth_amount: u256,
    }

    #[constructor]
    // Todo Checkpoint 2: Edit the constructor to initialize the owner of the contract.
    fn constructor(
        ref self: ContractState,
        eth_token_address: ContractAddress,
        your_token_address: ContractAddress,
        owner: ContractAddress,
    ) {
        self.eth_token.write(IERC20CamelDispatcher { contract_address: eth_token_address });
        self.your_token.write(IYourTokenDispatcher { contract_address: your_token_address });
        // ToDo Checkpoint 2: Initialize the owner of the contract here.
        self.ownable.initializer(owner);
    }
    #[abi(embed_v0)]
    impl VendorImpl of IVendor<ContractState> {
        // ToDo Checkpoint 2: Implement your function buy_tokens here.
        fn buy_tokens(
            ref self: ContractState, eth_amount_wei: u256
        ) { // Note: In UI and Debug contract `buyer` should call `approve`` before to `transfer` the amount to the `Vendor` contract.
            let caller = get_caller_address();
            let this = get_contract_address();

            let tokens_amount = eth_amount_wei * TokensPerEth;
            let this_tokens_balance = self.your_token.read().balance_of(this);
            assert(this_tokens_balance >= tokens_amount, 'not enought token balance');

            self.eth_token.read().transferFrom(caller, this, eth_amount_wei);
            self.your_token.read().transfer(caller, tokens_amount);

            self.emit(BuyTokens { buyer: caller, eth_amount: eth_amount_wei, tokens_amount });
        }

        // ToDo Checkpoint 2: Implement your function withdraw here.
        fn withdraw(ref self: ContractState) {
            self.ownable.assert_only_owner();

            let amount = self.eth_token.read().balanceOf(get_contract_address());

            self.eth_token.read().transfer(self.ownable.owner(), amount);
        }

        // ToDo Checkpoint 3: Implement your function sell_tokens here.
        fn sell_tokens(ref self: ContractState, amount_tokens: u256) {
            let caller = get_caller_address();
            let this = get_contract_address();

            self.your_token.read().transfer_from(caller, this, amount_tokens);
            let eth_this_amount = self.eth_token.read().balanceOf(this);

            let amount = amount_tokens / TokensPerEth;

            assert(eth_this_amount >= amount, 'eth balance not enough');

            self.eth_token.read().transfer(caller, amount);

            self
                .emit(
                    SellTokens { seller: caller, tokens_amount: amount_tokens, eth_amount: amount }
                );
        }

        // ToDo Checkpoint 2: Modify to return the amount of tokens per 1 ETH.
        fn tokens_per_eth(self: @ContractState) -> u256 {
            TokensPerEth
        }

        fn your_token(self: @ContractState) -> ContractAddress {
            self.your_token.read().contract_address
        }

        fn eth_token(self: @ContractState) -> ContractAddress {
            self.eth_token.read().contract_address
        }
    }
}
