#!/usr/bin/env coffee
## Script to convert a keystore with public keys as filenames to private keys as filenames
## Only to be used with private, test blockchains

keythereum = require('keythereum')
Promise = require('bluebird')
fs      = Promise.promisifyAll(require('fs'))

datadir = "geth"

for address in await fs.readdirAsync("#{datadir}/keystore")
  unless address.match(/^0x/)
    console.log(address)
    keyObject = keythereum.importFromFile(address, datadir)
    privatekey = keythereum.recover('', keyObject).toString('hex')
    fs.rename("#{datadir}/keystore/#{address}", "#{datadir}/keystore/0x#{privatekey}")
    console.log(privatekey)
