#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
mod Counter {
    use starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
      pub counter: u32,
      pub kill_switch: ContractAddress,
      #[substorage(v0)]
      ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event
    }
    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, counter: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
      self.ownable.initializer(initial_owner);
      self.counter.write(counter);
      self.kill_switch.write(kill_switch);
    }

    #[abi(embed_v0)]
    impl Counter of super::ICounter<ContractState> {
      fn get_counter(self: @ContractState) -> u32 {
        return self.counter.read();
      }

      fn increase_counter(ref self: ContractState) {
        self.ownable.assert_only_owner();
        assert!(!IKillSwitchDispatcher{contract_address: self.kill_switch.read()}.is_active(), "Kill Switch is active");
        
        let counter = self.counter.read();
        self.counter.write(counter + 1);
        self.emit(CounterIncreased {counter});
      }
    }
}
