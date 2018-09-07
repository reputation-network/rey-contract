Instachain = require('../lib/instachain')
ic = new Instachain(process.env.RPC_URL, "#{__dirname}/../app/contracts", "#{__dirname}/../geth")

writeContractInfo = (tag, abi, address, account) ->
  return if process.env.CONTRACT_INFO_PATH == undefined
  fs = require('fs-extra')
  path = require('path')
  contractInfoPath = path.resolve(process.env.CONTRACT_INFO_PATH || "./.contract")
  await fs.outputFile(path.resolve(contractInfoPath, tag, "./abi.json"), abi)
  await fs.outputFile(path.resolve(contractInfoPath, tag,  "./address"), address)
  await fs.outputFile(path.resolve(contractInfoPath, tag, "./account"), account)

deployContract = (contractTag, contractName) ->
  contractDeployment = await ic.deploy(contractName)
  contractInterface = ic.contracts[contractName].interface
  await writeContractInfo(contractTag, contractInterface, contractDeployment._address,
    contractDeployment.defaultAccount)
  console.log("Contract #{contractName} deployed at #{contractDeployment._address}")

(->
  await ic.init()
  await deployContract('rey', 'rey.sol:Rey')
  await deployContract('registry', 'registry.sol:Registry')
  console.log("Node's RPC URL: #{ic._rpcUrl}")
)()
