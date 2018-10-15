[ic, web3, expect, set] = require('../test')

Promise = require('bluebird')

describe 'rey', ->
  @timeout(300000) unless ic.testRPC?

  FUNDS  = web3.utils.toBN(web3.utils.toWei('100', 'ether'))
  FUTURE = '10000000000000000' # Future timestamp

  flatten = (obj) ->
    return [obj] unless typeof(obj) == 'object'
    output = []
    output = output.concat(flatten(x)) for x in obj
    output

  sign = (params, signer) ->
    message = web3.utils.soliditySha3(flatten(params)...)
    signature = (await web3.eth.sign(message, signer)).substr(2)
    v = parseInt(signature.substring(128, 130), 16)
    v += 27 if v < 27
    r = '0x' + signature.substring(0, 64)
    s = '0x' + signature.substring(64, 128)
    v = '0x' + v.toString(16)
    [r, s, v]

  set 'scoreAccount',        -> ic.accounts[0]
  set 'dataProviderAccount', -> ic.accounts[1]
  set 'userAccount',         -> ic.accounts[2]
  set 'verifierAccount',     -> ic.accounts[3]
  set 'clientAccount',       -> ic.accounts[9]

  before ->
    @contract = await ic.deploy('rey.sol:Rey')

  beforeEach -> await ic.unlockAccount(@clientAccount)

  it 'deploys contract', ->

  context 'escrow contract', ->
    context 'funding channel', ->
      context 'without existing funds', ->
        beforeEach ->
          await @contract.methods.fund(@scoreAccount, 0).send(from: @clientAccount, value: FUNDS)

        it 'funds channel', ->
          output = await @contract.methods.balance(@clientAccount, @scoreAccount).call()
          expect(output[0]).to.eql(FUNDS.toString())
          expect(output[1]).to.eql('0')

      context 'with existing funds', ->
        context 'with later expiration date', ->
          beforeEach ->
            await @contract.methods.fund(@scoreAccount, FUTURE).send(from: @clientAccount, value: FUNDS)

          it 'funds channel', ->
            output = await @contract.methods.balance(@clientAccount, @scoreAccount).call()
            expect(output[0]).to.eql(FUNDS.mul(web3.utils.toBN(2)).toString())
            expect(output[1]).to.eql(FUTURE.toString())

        context 'with sooner expiration date', ->
          it 'throws an error', ->
            await expect(@contract.methods.fund(@scoreAccount, 0).send(from: @clientAccount, value: FUNDS)).
                  to.eventually.be.rejected
            output = await @contract.methods.balance(@clientAccount, @scoreAccount).call()
            expect(output[0]).to.eql(FUNDS.mul(web3.utils.toBN(2)).toString())
            expect(output[1]).to.eql(FUTURE.toString())

    context 'releasing channel', ->
      context 'after expiration', ->
        beforeEach ->
          await @contract.methods.fund(@dataProviderAccount, 0).send(from: @clientAccount, value: FUNDS)
          @previousAccountBalance = web3.utils.toBN(await web3.eth.getBalance(@clientAccount))
          @previousChannelBalance = web3.utils.toBN((await @contract.methods.balance(@clientAccount,
                                                                                     @dataProviderAccount).call())[0])
          @tx = await @contract.methods.release(@dataProviderAccount).send(from: @clientAccount, gasPrice: 1)

        it 'releases channel', ->
          output = await @contract.methods.balance(@clientAccount, @dataProviderAccount).call()
          expect(output[0]).to.eql('0')
          expect(output[1]).to.eql('0')

        it 'sends funds back', ->
          gasUsed = web3.utils.toBN(@tx.gasUsed)
          newAccountBalance = web3.utils.toBN(await web3.eth.getBalance(@clientAccount))
          expectedBalance = web3.utils.toBN(@previousAccountBalance).add(@previousChannelBalance).sub(gasUsed)

          expect(newAccountBalance.toString()).to.eql(expectedBalance.toString())

      context 'before expiration', ->
        beforeEach ->
          await @contract.methods.fund(@dataProviderAccount, FUTURE).send(from: @clientAccount, value: FUNDS)

        it 'throws an error', ->
          await expect(@contract.methods.release(@dataProviderAccount).send(from: @clientAccount)).to.eventually.be.rejected
          output = await @contract.methods.balance(@clientAccount, @dataProviderAccount).call()
          expect(output[0]).to.eql(FUNDS.toString())
          expect(output[1]).to.eql(FUTURE.toString())

  context 'rey contract', ->
    # Basic transaction: score reading from data provider
    set 'transaction',              ->      [await @request, await @proof, await @transactionSignature]
    set 'transactionSignature',     -> sign([await @request, await @proof], @verifier)

    set 'request',                  ->      [await @readPermission, await @session, @counter, @value,
                                             await @requestSignature]
    set 'requestSignature',         -> sign([await @readPermission, await @session, @counter, @value], @scoreAccount)
    set 'counter',                  -> 1
    set 'value',                    -> web3.utils.toWei('1', 'ether')

    set 'proof',                    ->      [await @writePermission, await @session, await @proofSignature]
    set 'proofSignature',           -> sign([await @writePermission, await @session], @source)

    set 'readPermission',           ->      [@reader, @source, @subject, @manifest, @expiration, await @readPermissionSignature]
    set 'readPermissionSignature',  -> sign([@reader, @source, @subject, @manifest, @expiration], @subject)
    set 'manifest',                 -> '0x9dc83d95cbdfbff70d8f19c5cb7143f28a201bd99dc83d95cbdfbff70d8f19c5'
    set 'reader',                   -> @scoreAccount
    set 'source',                   -> @dataProviderAccount
    set 'subject',                  -> @userAccount
    set 'expiration',               -> FUTURE

    set 'writePermission',          ->      [@writer, @subject, await @writePermissionSignature]
    set 'writePermissionSignature', -> sign([@writer, @subject], @subject)
    set 'writer',                   -> @dataProviderAccount

    set 'session',                  ->      [@subject, @verifier, @fee, @nonce, await @sessionSignature]
    set 'sessionSignature',         -> sign([@subject, @verifier, @fee, @nonce], @subject)
    set 'verifier',                 -> @verifierAccount
    set 'fee',                      -> 1000
    set 'nonce',                    -> 12345

    context 'validating request', ->
      beforeEach ->
        await ic.unlockAccount(@userAccount)
        await ic.unlockAccount(@scoreAccount)
        await ic.unlockAccount(@dataProviderAccount)

      context 'with a valid request', ->
        set 'value', -> web3.utils.toWei('0', 'ether')
        it 'throws no error', ->
          await @contract.methods.validateRequest(await @request).call(from: @dataProviderAccount, gas: 150000000000)

      context 'with an invalid request', ->
        set 'value', -> web3.utils.toWei('1', 'ether')
        it 'throws an error', ->
          await expect(@contract.methods.validateRequest(await @request).call(from: @dataProviderAccount,
                                                                              gas: 150000000000))
                .to.eventually.be.rejected

    context 'cashing out', ->
      beforeEach ->
        await ic.unlockAccount(@userAccount)
        await ic.unlockAccount(@scoreAccount)
        await ic.unlockAccount(@dataProviderAccount)
        await ic.unlockAccount(@verifierAccount)
        await @contract.methods.fund(@dataProviderAccount, FUTURE).send(from: @scoreAccount, value: FUNDS)
        @previousAccountBalance = web3.utils.toBN(await web3.eth.getBalance(@dataProviderAccount))
        @previousVerifierBalance = web3.utils.toBN(await web3.eth.getBalance(@verifierAccount))
        @previousChannelBalance = web3.utils.toBN((await @contract.methods.balance(@scoreAccount,
                                                                                   @dataProviderAccount).call())[0])

      context 'with a valid transaction list', ->
        context 'with no transactions', ->
          it 'does nothing', ->
            await @contract.methods.cashout([]).send(from: @dataProviderAccount)

        context 'with a valid transaction', ->
          it 'cashes out', ->
            value2 = (@value * @fee) / 1000000

            @tx = await @contract.methods.cashout([await @transaction])
                                 .send(from: @dataProviderAccount, gas: 5000000, gasPrice: 1)

            newAccountBalance = web3.utils.toBN(await web3.eth.getBalance(@dataProviderAccount))
            expectedAccountBalance = @previousAccountBalance.add(web3.utils.toBN(@value))
                                                            .sub(web3.utils.toBN(value2))
                                                            .sub(web3.utils.toBN(@tx.gasUsed))
            expect(newAccountBalance.toString()).to.eql(expectedAccountBalance.toString())

            newVerifierBalance = web3.utils.toBN(await web3.eth.getBalance(@verifierAccount))
            expectedVerifierBalance = @previousVerifierBalance.add(web3.utils.toBN(value2))
            expect(newVerifierBalance.toString()).to.eql(expectedVerifierBalance.toString())

            newChannelBalance = web3.utils.toBN((await @contract.methods.balance(@scoreAccount,
                                                                                 @dataProviderAccount).call())[0])
            expect(newChannelBalance.toString()).to.eql(@previousChannelBalance.sub(web3.utils.toBN(@value)).toString())

            transactionEvents = await @contract.getPastEvents 'Cashout', {filter: {subject: @subject}}
            expect(transactionEvents.length).to.eql(1)
            expect(transactionEvents[0].returnValues.transaction.request.session.subject).to.eql(@subject)

        context 'with more than one valid transaction', ->
          set 'transaction2',          ->      [await @request2, await @proof, await @transactionSignature2]
          set 'transactionSignature2', -> sign([await @request2, await @proof], @verifier)
          set 'request2',              ->      [await @readPermission, await @session, @counter2, @value,
                                                await @requestSignature2]
          set 'requestSignature2',     -> sign([await @readPermission, await @session, @counter2, @value],
                                                @scoreAccount)
          set 'counter',               -> 2
          set 'counter2',              -> 3

          it 'cashes out', ->
            value2 = (@value * @fee) / 1000000

            @tx = await @contract.methods.cashout([await @transaction, await @transaction2])
                                 .send(from: @dataProviderAccount, gas: 5000000, gasPrice: 1)

            newAccountBalance = web3.utils.toBN(await web3.eth.getBalance(@dataProviderAccount))
            expectedAccountBalance = @previousAccountBalance.add(web3.utils.toBN(@value * 2))
                                                            .sub(web3.utils.toBN(value2 * 2))
                                                            .sub(web3.utils.toBN(@tx.gasUsed))
            expect(newAccountBalance.toString()).to.eql(expectedAccountBalance.toString())

            newVerifierBalance = web3.utils.toBN(await web3.eth.getBalance(@verifierAccount))
            expectedVerifierBalance = @previousVerifierBalance.add(web3.utils.toBN(value2 * 2))
            expect(newVerifierBalance.toString()).to.eql(expectedVerifierBalance.toString())

            newChannelBalance = web3.utils.toBN((await @contract.methods.balance(@scoreAccount,
                                                                                 @dataProviderAccount).call())[0])
            expect(newChannelBalance.toString())
              .to.eql(@previousChannelBalance.sub(web3.utils.toBN(@value * 2)).toString())

            transactionEvents = await @contract.getPastEvents 'Cashout', {filter: {subject: @subject}}
            expect(transactionEvents.length).to.eql(2)

        context 'with an invalid transaction', ->
          set 'counter', -> 4

          context 'with an invalid signature', ->
            it 'throws an error'

          context 'with not enough funds', ->
            set 'value', -> web3.utils.toWei('100000000000000000', 'ether')

            it 'throws an error', ->
              await expect(@contract.methods.cashout([await @transaction])
                           .call(from: @dataProviderAccount, gas: 150000000000)).to.eventually.be.rejected

          context 'with an invalid read permission', ->
            context 'with an invalid signature', ->
              it 'throws an error'

            context 'with an expired permission', ->
              it 'throws an error'

            context 'with an incorrect subject', ->
              it 'throws an error'

            context 'with an incorrect reader', ->
              it 'throws an error'

            context 'with an incorrect source', ->
              it 'throws an error'

          context 'with an invalid write permission', ->
            context 'with an invalid signature', ->
              it 'throws an error'

            context 'with an incorrect subject', ->
              it 'throws an error'

            context 'with an incorrect writer', ->
              it 'throws an error'

          context 'with an invalid session', ->
            context 'with an incorrect subject', ->
              it 'throws an error'

            context 'with an invalid verifier', ->
              it 'throws an error'

            context 'with an invalid fee', ->
              set 'fee', -> 1000000000

              it 'throws an error', ->
                await expect(@contract.methods.cashout([await @transaction])
                             .call(from: @dataProviderAccount, gas: 150000000000)).to.eventually.be.rejected

            context 'with an invalid signature', ->
              it 'throws an error'

          context 'with an invalid request', ->
            context 'with an invalid signature', ->
              it 'throws an error'

            context 'with an invalid counter', ->
              set 'counter', -> 0

              it 'throws an error', ->
                await expect(@contract.methods.cashout([await @transaction])
                             .call(from: @dataProviderAccount, gas: 150000000000)).to.eventually.be.rejected

          context 'with an invalid proof', ->
            context 'with an invalid signature', ->
              it 'throws an error'

          context 'with non-matching permissions', ->
            it 'throws an error'

          context 'with non-matching sessions', ->
            it 'throws an error'

      context 'with an invalid transaction list', ->
        it 'throws an error'
