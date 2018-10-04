pragma solidity ^0.4.24;

contract Registry {

  struct Entry {
    string value;
    bytes32 hash;
  }

  mapping(address => Entry) entries;

  function setEntry(string _value, bytes32 _hash) public {
    entries[msg.sender] = Entry(_value, _hash);
  }

  function getEntry(address _address) public view returns(string, bytes32) {
    return (entries[_address].value, entries[_address].hash);
  }
}
