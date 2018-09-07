REY Contract
============

REY's smart contracts.

Installation
------------

To install dependencies:

    npm install

To initialize a private blockchain:

    npm run init

Usage
-----

To run tests using TestRPC (fast dummy blockchain):

    npm test

To run tests using Geth node (more realistic), first start the node (it should be initialized with `npm run init`, as mentioned in the Installation section):

    npm run geth

and, in another console, run the tests:

    RPC_URL=http://localhost:8545 npm run test

To deploy the contract using TestRPC:

    npm start

and using Geth (execution will stop, as the node is running in a different process):

    RPC_URL=http://localhost:8545 npm start
