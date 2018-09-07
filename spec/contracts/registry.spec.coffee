[ic, web3, expect, set] = require('../test')

Promise = require('bluebird')

describe 'registry', ->
  @timeout(300000) unless ic.testRPC?

  set 'appAccount',   -> ic.accounts[0]
  set 'otherAccount', -> ic.accounts[1]
  set 'entry',        -> 'http://entry'
  set 'entryTwo',     -> 'http://entryTwo'

  before ->
    @contract = await ic.deploy('registry.sol:Registry')
    console.log('Registry contract deployed at', @contract.options.address)

  it 'deploys contract', ->

  context 'entry management', ->
    context 'sets a new entry', ->
      beforeEach ->
        await @contract.methods.setEntry(@entry).send(from: @appAccount)

      it 'sets the new entry', ->
        entry = await @contract.methods.getEntry(@appAccount).call()
        expect(entry).to.eql(@entry)

    context 'sets an already existing entry', ->
      beforeEach ->
        await @contract.methods.setEntry(@entryTwo).send(from: @appAccount)

      it 'sets the entry', ->
        entry = await @contract.methods.getEntry(@appAccount).call()
        expect(entry).to.eql(@entryTwo)

    context 'gets an not existing entry', ->
      it 'is non setted', ->
        entry = await @contract.methods.getEntry(@otherAccount).call()
        expect(entry).to.eql('')
