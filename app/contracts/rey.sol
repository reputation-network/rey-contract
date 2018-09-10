pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import './escrow.sol';

contract Rey is Escrow {
  mapping(bytes32 => uint) public counters;
  Transaction[] public transactionHistory;

  struct Transaction {
    Request request;
    Proof proof;
    Signature signature;
  }

  struct Request {
    ReadPermission readPermission;
    Session session;
    uint counter;
    uint value;
    Signature signature;
  }

  struct Proof {
    WritePermission writePermission;
    Session session;
    Signature signature;
  }

  struct ReadPermission {
    address reader;
    address source;
    address subject;
    uint expiration;
    Signature signature;
  }

  struct WritePermission {
    address writer;
    address subject;
    Signature signature;
  }

  struct Session {
    address subject;
    address verifier;
    uint fee; // in parts per million
    uint nonce;
    Signature signature;
  }

  struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  function cashout(Transaction[] transactions) public {
    for (uint i = 0; i < transactions.length; i++) {
      validateTransaction(transactions[i]);
      cashoutValidTransaction(transactions[i]);
    }
  }

  function cashoutValidTransaction(Transaction transaction) private {
    uint fee = transaction.request.session.fee * transaction.request.value / 1000000;
    super.cashout(transaction.request.readPermission.reader, transaction.request.value,
                  transaction.request.session.verifier, fee);
    bytes32 channel = super.channel(transaction.request.readPermission.reader,
                                    transaction.request.readPermission.source);
    counters[channel] = transaction.request.counter;
    transactionHistory.push(transaction);
  }

  function validateTransaction(Transaction transaction) private view {
    validateMatchingRequestAndProof(transaction.request, transaction.proof);
    validateMatchingSession(transaction);
    validateRequest(transaction.request);
    validateProof(transaction.proof);
    validateSignature(hash(serializeTransaction(transaction)), transaction.signature,
                      transaction.request.session.verifier);
  }

  function validateMatchingRequestAndProof(Request request, Proof proof) private pure {
    require(request.readPermission.subject == proof.writePermission.subject, 'Permissions subject do not match');
  }

  function validateMatchingSession(Transaction transaction) private pure {
    require(transaction.request.session.subject == transaction.proof.session.subject, 'Sessions do not match');
    require(transaction.request.session.verifier == transaction.proof.session.verifier, 'Sessions do not match');
    require(transaction.request.session.fee == transaction.proof.session.fee, 'Sessions do not match');
    require(transaction.request.session.nonce == transaction.proof.session.nonce, 'Sessions do not match');
  }

  function validateRequest(Request request) public view returns(bool) {
    validateReadPermission(request.readPermission);
    validateSession(request.session);
    validateSignature(hash(serializeRequest(request)), request.signature, request.readPermission.reader);
    require(request.session.subject == request.readPermission.subject, 'Session subject does not match');
    require(request.readPermission.source == msg.sender, 'Invalid source');
    bytes32 channel = super.channel(request.readPermission.reader, request.readPermission.source);
    require(counters[channel] < request.counter, 'Invalid counter');
    require(balances[channel].value >= request.value, 'Insufficient funds in channel');
    return true;
  }

  function validateProof(Proof proof) private pure {
    validateWritePermission(proof.writePermission);
    validateSession(proof.session);
    validateSignature(hash(serializeProof(proof)), proof.signature, proof.writePermission.writer);
  }

  function validateReadPermission(ReadPermission readPermission) private view {
    require(readPermission.expiration > now, 'Read permission has expired');
    validateSignature(hash(serializeReadPermission(readPermission)),
                      readPermission.signature, readPermission.subject);
  }

  function validateWritePermission(WritePermission writePermission) private pure {
    validateSignature(hash(serializeWritePermission(writePermission)),
                      writePermission.signature, writePermission.subject);
  }

  function validateSession(Session session) private pure {
    validateSignature(hash(serializeSession(session)), session.signature, session.subject);
  }

  function validateSignature(bytes32 h, Signature signature, address addr) private pure {
    require(ecrecover(h, signature.v, signature.r, signature.s) == addr, 'Invalid signature');
  }

  function serializeSession(Session session) private pure returns(bytes) {
    return abi.encodePacked(session.subject, session.verifier, session.fee, session.nonce);
  }

  function serializeWritePermission(WritePermission writePermission) private pure returns(bytes) {
    return abi.encodePacked(writePermission.writer, writePermission.subject);
  }

  function serializeReadPermission(ReadPermission readPermission) private pure returns(bytes) {
    return abi.encodePacked(readPermission.reader, readPermission.source,
                            readPermission.subject, readPermission.expiration);
  }

  function serializeProof(Proof proof) private pure returns(bytes) {
    return abi.encodePacked(serializeWritePermission(proof.writePermission),
                            serializeSignature(proof.writePermission.signature),
                            serializeSession(proof.session),
                            serializeSignature(proof.session.signature));
  }

  function serializeRequest(Request request) private pure returns(bytes) {
    return abi.encodePacked(serializeReadPermission(request.readPermission),
                            serializeSignature(request.readPermission.signature),
                            serializeSession(request.session),
                            serializeSignature(request.session.signature),
                            request.counter, request.value);
  }

  function serializeTransaction(Transaction transaction) private pure returns(bytes) {
    return abi.encodePacked(serializeRequest(transaction.request),
                            serializeSignature(transaction.request.signature),
                            serializeProof(transaction.proof),
                            serializeSignature(transaction.proof.signature));
  }

  function serializeSignature(Signature signature) private pure returns(bytes) {
    return abi.encodePacked(signature.r, signature.s, signature.v);
  }

  function hash(bytes message) private pure returns(bytes32) {
    return keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', keccak256(message)));
  }
}
