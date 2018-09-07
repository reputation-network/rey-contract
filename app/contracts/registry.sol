pragma solidity ^0.4.24;

contract Registry {

  mapping(address => string) entries;

  function setEntry(string _entry) public {
    entries[msg.sender] = _entry;
  }

  function getEntry(address _address) public view returns(string) {
    return entries[_address];
  }
}
