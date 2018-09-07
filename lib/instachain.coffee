Promise = require('bluebird')
fs      = Promise.promisifyAll(require('fs'))
solc    = require('solc')
Web3    = require('web3')
ganache = require('ganache-core')

module.exports = class Instachain
  TEST_PORT = 8546

  constructor: (rpcUrl, contractsPath, gethPath) ->
    @_contractsPath = contractsPath
    @_gethPath = gethPath
    @_runTestRPC() unless rpcUrl?
    @_rpcUrl = rpcUrl || "http://localhost:#{TEST_PORT}"
    @web3 = new Web3(@_rpcUrl)
    @_extendWeb3()

  init: ->
    contractFiles = await @_readContractFiles()
    await @_compileContracts(contractFiles)
    await @_readAccounts()
    await @web3.miner.start() unless @testRPC?
    @web3.eth.defaultAccount ||= @accounts[0]

  finalize: ->
    if @testRPC?
      @testRPC.close()
    else
      @web3.miner.stop()

  deploy: (name, args...) ->
    await @unlockAccount(@web3.eth.defaultAccount)
    contract = new @web3.eth.Contract(JSON.parse(@contracts[name].interface))
    contract.deploy(data: "0x#{@contracts[name].bytecode}", arguments: args)
    .send(from: @web3.eth.defaultAccount, gas: 4000000, gasPrice: 1)

  unlockAccount: (account) ->
    return Promise.resolve() if @testRPC?
    @web3.eth.personal.unlockAccount(account)

  _compileContracts: (contractFiles) ->
    output = solc.compile({ sources: contractFiles }, 1)
    if output.errors?
      console.error(e) for e in output.errors
      throw new Error(output.errors) if (e for e in output.errors when e.indexOf('Error') != -1).length != 0
    @contracts = output.contracts

  _readContractFiles: ->
    files = await fs.readdirAsync(@_contractsPath)
    result = await Promise.all(for file in files when file.match(/\.sol$/)
      out = await fs.readFileAsync("#{@_contractsPath}/#{file}")
      [file, out.toString('utf8')]
    )
    contractFiles = {}
    contractFiles[file] = code for [file, code] in result
    contractFiles

  _extendWeb3: ->
    @web3.extend(
      property: 'miner',
      methods: [{ name: 'start', call: 'miner_start' }, { name: 'stop', call: 'miner_stop' }]
    )

  _readAccounts: ->
    @accounts = await @web3.eth.getAccounts()

  _runTestRPC: ->
    files = fs.readdirSync("#{@_gethPath}/keystore")
    balance = "10000000000000000000000000000"
    accounts = ({ secretKey: file, balance: balance } for file in files when file.match(/^0x/))
    # Accounts need to be unlocked because of Ganache bug: github.com/trufflesuite/ganache-cli/issues/405
    @testRPC = ganache.server(accounts: accounts, locked: false, networkId: 666, gasLimit: 400000000000)
    @testRPC.listen(TEST_PORT)
