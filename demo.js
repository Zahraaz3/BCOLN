import { ethers } from "ethers";
import accounts from "./accounts.json" with { type: "json" };;
import contracts from "./contracts/addresses.json" with { type: "json" };
import supplyChainContractAbi from "./contracts/SupplyChainContract/abi.json" with { type: "json"}
import tokenContractAbi from "./contracts/ERC20Contract/abi.json" with { type: "json"}
import axios from "axios"
import status from "./statuses.json" with { type: "json"};

import fs from "fs"
const owner = accounts[0];
const seller = accounts[1];
const distributorToWarehouse = accounts[2];
const warehouse = accounts[3];
const doorToDoorDelivery = accounts[4];
const productBuyer = accounts[5];
const provider = new ethers.providers.JsonRpcProvider()
const supplyChainContract = new ethers.Contract(
    contracts.supplyChain,
    supplyChainContractAbi
);
function _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
//   function _sleep(ms) {
//     return new Promise(resolve => setTimeout(resolve, 1));
//   }
const tokenContract = new ethers.Contract(
    contracts.token,
    tokenContractAbi
);
const _addFunds = async(logText, to, amount) => {
    const vContract = tokenContract.connect(new ethers.Wallet(owner.privateKey, provider))
    console.log(logText)
    const transaction = await vContract.mint(to, amount)
    console.log(transaction)
    await _sleep(1000)
}


const uploadProductToIpfs = async () => {
    const filePath =  'tshirt.jpg';
    const imageBuffer = fs.readFileSync(filePath);
    const base64Image = imageBuffer.toString('base64');
    const name = "T Shirt"
    const description = "Good Design Tshirt"
    const response = await axios.post("http://localhost:8000/add", {
        name,
        description,
        base64Image
    })
    return response.data.cid

}
const _requestStatusChange = async (id, privateKey, status, logText) => {
    const wallet = new ethers.Wallet(privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log(logText)
    const transaction = await contract.requestStatusChange(id,status)
    console.log(transaction)
    await _sleep(1000)
}

const _approveStatusChange = async (id, privateKey, idx, logText) => {
    const wallet = new ethers.Wallet(privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log(logText)
    const transaction = await contract.approveStatusChange(id, idx, {gasLimit: 1000000})
    console.log(transaction)
    await _sleep(1000)
}

const _uploadProduct = async(cid, price, privateKey) => {
    const wallet = new ethers.Wallet(privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log("Uploading Product")
    const transaction = await contract.uploadProduct(cid, price)
    console.log(transaction)
    await _sleep(1000)

}
const _getProductId = async (cid) => {
    const wallet = new ethers.Wallet(owner.privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    const response = await contract.getProductId(cid)
    return response
}
const _getProduct = async (id) => {
    const idStr = id.toString()
    console.log("Getting Product " , id, idStr)
    const wallet = new ethers.Wallet(owner.privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    const response = await contract.products(idStr)
    console.log(response)
}
const _enrollRequest = async(logText, role, privateKey) => {
    const wallet = new ethers.Wallet(privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log(logText)
    const transaction = await contract.requestEnrollment(role)
    console.log(transaction)
    await _sleep(1000)
}
const _approveEnrollRequest = async (logText, address) => {
    const wallet = new ethers.Wallet(owner.privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log(logText)
    const transaction = await contract.approveEnrollment(address)
    console.log(transaction)
    await _sleep(1000)

}
const _statusCheck = async(address, name) => {
    const wallet = new ethers.Wallet(owner.privateKey, provider)
    const contract = supplyChainContract.connect(wallet)
    console.log("Status check of user type " + name)
    const response = await contract.users(address)
    console.log(response)
    await _sleep(1000)
}
const _checkBalance =  async(address, name) => {
    const wallet = new ethers.Wallet(owner.privateKey, provider)
    const contract = tokenContract.connect(wallet)
    console.log("Balance check of user type " + name)
    const response = await contract.balanceOf(address)
    console.log(response.toString())
    await _sleep(1000)
}

await _enrollRequest("Enrollment request of Product Seller", status.roles.ProductSeller, seller.privateKey)
await _enrollRequest("Enrollment request of Distributor To Warehouse", status.roles.DistributorToWarehouse, distributorToWarehouse.privateKey)
await _enrollRequest("Enrollment request of Warehouse ", status.roles.Warehouse, warehouse.privateKey)
await _enrollRequest("Enrollment request of Door To Door Delivery", status.roles.DoorToDoorDelivery, doorToDoorDelivery.privateKey)
await _enrollRequest("Enrollment request of Product Buyer", status.roles.ProductBuyer, productBuyer.privateKey)

// await _statusCheck(seller.publicKey, "Product Seller")
// await _statusCheck(distributorToWarehouse.publicKey, "Distributor To Warehouse")
// await _statusCheck(warehouse.publicKey, "Warehouse")
// await _statusCheck(doorToDoorDelivery.publicKey, "Door To Door Delivery")
// await _statusCheck(productBuyer.publicKey, "Product Buyer")

await _approveEnrollRequest("Approve Enroll request of Product Seller", seller.publicKey)
await _approveEnrollRequest("Approve Enroll request of Distributor To Warehouse", distributorToWarehouse.publicKey)
await _approveEnrollRequest("Approve Enroll request of Warehouse", warehouse.publicKey)
await _approveEnrollRequest("Approve Enroll request of Door To Door Delivery", doorToDoorDelivery.publicKey)
await _approveEnrollRequest("Approve Enroll request of Product Buyer", productBuyer.publicKey)

// await _statusCheck(seller.publicKey, "Product Seller")
// await _statusCheck(distributorToWarehouse.publicKey, "Distributor To Warehouse")
// await _statusCheck(warehouse.publicKey, "Warehouse")
// await _statusCheck(doorToDoorDelivery.publicKey, "Door To Door Delivery")
// await _statusCheck(productBuyer.publicKey, "Product Buyer")

await _addFunds("Adding Fund to Seller Account", seller.publicKey, 10000)
await _addFunds("Adding Fund to Distributor To Warehouse Account", distributorToWarehouse.publicKey, 10000)
await _addFunds("Adding Fund to Warehouse Account", warehouse.publicKey, 10000)
await _addFunds("Adding Fund to Door To Door Delivery Account", doorToDoorDelivery.publicKey, 10000)
await _addFunds("Adding Fund to Product Buyer Account", productBuyer.publicKey, 10000)

// await _checkBalance(seller.publicKey, "Product Seller")
// await _checkBalance(distributorToWarehouse.publicKey, "Distributor To Warehouse")
// await _checkBalance(warehouse.publicKey, "Warehouse")
// await _checkBalance(doorToDoorDelivery.publicKey, "Door To Door Delivery")
// await _checkBalance(productBuyer.publicKey, "Product Buyer")

const cid = await uploadProductToIpfs()
await _uploadProduct(cid, 100, seller.privateKey)
const productId = await _getProductId(cid) 
await _requestStatusChange(productId, productBuyer.privateKey, status.statuses.ReadyToShip, "Buyer is requesting to order")
await _approveStatusChange(productId, seller.privateKey, 0, "Seller Accepted the request")



// await _requestStatusChange(productId, distributorToWarehouse.privateKey, status.statuses.Shipping, "Distributor requested for handover")
// await _approveStatusChange(productId, seller.privateKey, 1, "Seller has handed over the product")
// await _checkBalance(seller.publicKey, "Product Seller")
// await _checkBalance(distributorToWarehouse.publicKey, "Distributor To Warehouse")
// await _checkBalance(warehouse.publicKey, "Warehouse")
// await _checkBalance(doorToDoorDelivery.publicKey, "Door To Door Delivery")
// await _checkBalance(productBuyer.publicKey, "Product Buyer")
// await _getProduct(productId)

