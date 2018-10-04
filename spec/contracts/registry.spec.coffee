[ic, web3, expect, set] = require('../test')

Promise = require('bluebird')

describe 'registry', ->
  @timeout(300000) unless ic.testRPC?

  set 'appAccount',   -> ic.accounts[0]
  set 'otherAccount', -> ic.accounts[1]
  set 'value',        -> 'http://value'
  set 'hash',         -> '0x9dc83d95cbdfbff70d8f19c5cb7143f28a201bd99dc83d95cbdfbff70d8f19c5'
  set 'value2',       -> 'http://value2'
  set 'hash2',        -> '0x28a201bd99dc83d95cbdfbff70d8f19c59dc83d95cbdfbff70d8f19c5cb7143f'

  before ->
    @contract = await ic.deploy('registry.sol:Registry')

  it 'deploys contract', ->

  context 'entry management', ->
    context 'sets a new entry', ->
      beforeEach ->
        await @contract.methods.setEntry(@value, @hash).send(from: @appAccount)

      it 'sets the new entry', ->
        output = await @contract.methods.getEntry(@appAccount).call()
        expect(output[0]).to.eql(@value)
        expect(output[1]).to.eql(@hash)

    context 'sets an already existing entry', ->
      beforeEach ->
        await @contract.methods.setEntry(@value2, @hash2).send(from: @appAccount)

      it 'sets the entry', ->
        output = await @contract.methods.getEntry(@appAccount).call()
        expect(output[0]).to.eql(@value2)
        expect(output[1]).to.eql(@hash2)

    context 'gets a non-existing entry', ->
      it 'is non setted', ->
        output = await @contract.methods.getEntry(@otherAccount).call()
        expect(output[0]).to.eql('')
        expect(output[1]).to.eql('0x0000000000000000000000000000000000000000000000000000000000000000')
