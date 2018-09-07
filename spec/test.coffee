chai = require('chai')
chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)
set = require('mocha-let')

Instachain = require('../lib/instachain')
instachain = new Instachain(process.env.RPC_URL, "#{__dirname}/../app/contracts", "#{__dirname}/../geth")

before ->
  @timeout(50000)
  instachain.init()

after -> instachain.finalize()

module.exports = [instachain, instachain.web3, chai.expect, set]
