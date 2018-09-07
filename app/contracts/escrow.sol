pragma solidity ^0.4.24;

contract Escrow {
  struct Balance {
    uint value;
    uint expiration;
  }

  mapping(bytes32 => Balance) balances;

  function fund(address to, uint expiration) public payable {
    require(balances[channel(msg.sender, to)].expiration <= expiration);

    uint previousAmount = balances[channel(msg.sender, to)].value;

    balances[channel(msg.sender, to)] = Balance(previousAmount + msg.value, expiration);
  }

  function release(address to) public {
    Balance memory currentBalance = balances[channel(msg.sender, to)];
    require(currentBalance.expiration <= now);

    msg.sender.transfer(currentBalance.value);
    currentBalance.value = 0;

    balances[channel(msg.sender, to)] = currentBalance;
  }

  function balance(address from, address to) public view returns(uint, uint) {
    Balance memory currentBalance = balances[channel(from, to)];
    return (currentBalance.value, currentBalance.expiration);
  }

  function cashout(address from, uint value, address middleman, uint value2) internal {
    Balance memory currentBalance = balances[channel(from, msg.sender)];

    require(currentBalance.value >= value);

    msg.sender.transfer(value - value2);
    middleman.transfer(value2);

    currentBalance.value -= value;

    balances[channel(from, msg.sender)] = currentBalance;
  }

  function channel(address from, address to) internal pure returns(bytes32) {
    return keccak256(abi.encodePacked(from, to));
  }
}
