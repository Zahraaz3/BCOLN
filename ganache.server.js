const ganache = require("ganache");
const fs = require("fs")
const options = {};
const server = ganache.server(options);
const PORT = 8545; 
const { ethers } = require("ethers");
server.listen(PORT, async err => {
  if (err) throw err;

  console.log(`ganache listening on port ${server.address().port}...`);
  const provider = server.provider;
  const accounts = provider.getInitialAccounts()
  const accountAra = []
  for (const key of Object.keys(accounts)){
    accountAra.push({
      publicKey: key,
      privateKey: accounts[key].secretKey
    })
  }
  fs.writeFileSync("./accounts.json", JSON.stringify(accountAra))
  const ethprovider = new ethers.providers.JsonRpcProvider();
  const signer = ethprovider.getSigner()
  const supplyChainContract = await _deployContract("SupplyChainContract", require("./contracts/SupplyChainContract/abi.json"), require("./contracts/SupplyChainContract/bytecode.json").bytecode.object, signer)
  const tokenAddress = await supplyChainContract.connect(signer).tokenAddress()
  fs.writeFileSync("./contracts/addresses.json", JSON.stringify({
    supplyChain: supplyChainContract.address,
    token: tokenAddress.toString()
  }))
  
});
const _deployContract = async(contractName, abi, bytecode, signer, args = []) => {
  console.log(`deploying ${contractName}`)


  const factory = new ethers.ContractFactory(abi, bytecode, signer)

  const contract = await factory.deploy(...args)

  // The contract is NOT deployed yet; we must wait until it is mined
  await contract.deployed()
  return contract
}