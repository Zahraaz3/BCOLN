// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
abstract contract BaseSupplyChain {
    enum Role { ProductSeller, DistributorToWarehouse, Warehouse, DoorToDoorDelivery, ProductBuyer }
    enum Status { Available, ReadyToShip, Shipping, Shipped, ReadyForDelivery, OutForDelivery, Delivered }
    struct StatusChangePayment { uint256 amount; Role payer; Role receiver; bool isPercentage; }
    mapping(uint256 => mapping(Status => StatusChangePayment)) public statusChangePayments;
    modifier onlyDesignatedPayer(uint256 productId, Status to) {
        require(users[msg.sender].role == statusChangePayments[productId][to].payer, "Not authorized payer"); _;
    }
    function _getPaymentAmount(uint256 productId, Status to) internal view returns (uint256) {
        StatusChangePayment storage p = statusChangePayments[productId][to];
        return p.isPercentage ? products[productId].price * p.amount / 100 : p.amount;
    }
    modifier isEligibleForStatusChange(uint256 productId, Status to) {
        require(_isEligibleForStatusChange(products[productId], users[msg.sender].role, to), "Not eligible for status change"); _;
    }
    modifier isEligibleForApproval(uint256 productId, uint256 idx) {
        StatusChangeRequest storage r = productRequests[productId][idx];
        require(!r.accepted && _isEligibleForApproval(products[productId], users[msg.sender].role, r.to), "Not allowed"); _;
    }
    modifier hasSufficientPayment(uint256 productId, Status to) {
        require(msg.value >= _getPaymentAmount(productId, to), "Insufficient payment"); _;
    }
    struct User { address id; Role role; bool isApproved; }
    struct Product { uint256 id; string cid; string externalReference; Status status; uint256 price; address seller; address buyer; address distributor; address warehouse; address delivery; }
    struct StatusChangeRequest { uint256 productId; Status from; Status to; address requester; bool accepted; }
    mapping(address => User) public users;
    mapping(uint256 => Product) public products;
    mapping(uint256 => StatusChangeRequest[]) public productRequests;
    function _isEligibleForStatusChange(Product storage p, Role r, Status t) internal view returns (bool) {
        if (t == Status.ReadyToShip) return r == Role.ProductBuyer && p.status == Status.Available;
        if (t == Status.Shipping) return r == Role.DistributorToWarehouse && p.status == Status.ReadyToShip;
        if (t == Status.Shipped) return r == Role.DistributorToWarehouse && p.status == Status.Shipping;
        if (t == Status.ReadyForDelivery) return r == Role.DoorToDoorDelivery && p.status == Status.Shipped;
        if (t == Status.OutForDelivery) return r == Role.DoorToDoorDelivery && p.status == Status.ReadyForDelivery;
        if (t == Status.Delivered) return r == Role.DoorToDoorDelivery && p.status == Status.OutForDelivery;
        return false;
    }
    function _isEligibleForApproval(Product storage p, Role r, Status t) internal view returns (bool) {
        if (t == Status.ReadyToShip || t == Status.Shipping) return r == Role.ProductSeller;
        if (t == Status.Shipped || t == Status.ReadyForDelivery || t == Status.OutForDelivery) return r == Role.Warehouse;
        if (t == Status.Delivered) return r == Role.ProductBuyer;
        return false;
    }
}
 
contract SupplyChainContract is BaseSupplyChain {
    address public owner;
    uint256 public nextProductId;
    event EnrollRequested(address indexed u, Role r);
    event EnrollApproved(address indexed u, Role r);
    event ProductUploaded(uint256 indexed id, string cid, uint256 price, string ext);
    event StatusChangeRequested(uint256 indexed id, Status from, Status to, address requester);
    event StatusChangeApproved(uint256 indexed id, Status from, Status to, address approver);
    event PaymentTransferred(address indexed to, uint256 amt);
    modifier onlyOwner() { require(msg.sender == owner, "Only owner"); _; }
    modifier onlyApproved() { require(users[msg.sender].isApproved, "Not approved"); _; }
    modifier notEnrolled() { require(!users[msg.sender].isApproved, "Already enrolled"); _; }
    modifier validRequestIndex(uint256 pid, uint256 idx) { require(idx < productRequests[pid].length, "Invalid index"); _; }
    modifier isCorrectRequester(uint256 pid, uint256 idx) { require(productRequests[pid][idx].requester == msg.sender, "Not requester"); _; }
    constructor() { owner = msg.sender; }
    function requestEnrollment(Role r) external notEnrolled {
        users[msg.sender] = User(msg.sender, r, false);
        emit EnrollRequested(msg.sender, r);
    }
    function approveEnrollment(address u) external onlyOwner {
        users[u].isApproved = true;
        emit EnrollApproved(u, users[u].role);
    }
    function uploadProduct(string calldata cid, uint256 price, string calldata extRef) external onlyApproved {
        require(users[msg.sender].role == Role.ProductSeller, "Only seller");
        products[nextProductId] = Product(nextProductId, cid, extRef, Status.Available, price, msg.sender, address(0), address(0), address(0), address(0));
        _configureDefaultPayments(nextProductId);
        emit ProductUploaded(nextProductId, cid, price, extRef);
        nextProductId++;
    }
    function _configureDefaultPayments(uint256 pid) internal {
        statusChangePayments[pid][Status.ReadyToShip] = StatusChangePayment(0, Role.ProductBuyer, Role.ProductSeller, false);
        statusChangePayments[pid][Status.Shipping] = StatusChangePayment(10, Role.ProductBuyer, Role.DistributorToWarehouse, false);
        statusChangePayments[pid][Status.Shipped] = StatusChangePayment(5, Role.ProductSeller, Role.Warehouse, true);
        statusChangePayments[pid][Status.ReadyForDelivery] = StatusChangePayment(2, Role.DistributorToWarehouse, Role.DoorToDoorDelivery, false);
        statusChangePayments[pid][Status.OutForDelivery] = StatusChangePayment(1, Role.Warehouse, Role.DoorToDoorDelivery, false);
        statusChangePayments[pid][Status.Delivered] = StatusChangePayment(3, Role.ProductBuyer, Role.DoorToDoorDelivery, true);
    }
    function requestStatusChange(uint256 pid, Status to) external onlyApproved isEligibleForStatusChange(pid, to) {
        Product storage p = products[pid];
        productRequests[pid].push(StatusChangeRequest(pid, p.status, to, msg.sender, false));
        emit StatusChangeRequested(pid, p.status, to, msg.sender);
    }
    function approveStatusChange(uint256 pid, uint256 idx) external payable onlyApproved validRequestIndex(pid, idx) isEligibleForApproval(pid, idx) isCorrectRequester(pid, idx) onlyDesignatedPayer(pid, productRequests[pid][idx].to) hasSufficientPayment(pid, productRequests[pid][idx].to) {
        _approveAndPay(pid, idx);
    }
    function _approveAndPay(uint256 pid, uint256 idx) internal {
        StatusChangeRequest storage r = productRequests[pid][idx];
        Product storage p = products[pid];
        Status to = r.to;
        address who = r.requester;
        if (to == Status.ReadyToShip) p.buyer = who;
        else if (to == Status.Shipping) p.distributor = who;
        else if (to == Status.Shipped) p.warehouse = who;
        else if (to == Status.ReadyForDelivery || to == Status.OutForDelivery) p.delivery = who;
        p.status = to;
        r.accepted = true;
        uint256 amt = _getPaymentAmount(pid, to);
        (bool sent, ) = payable(who).call{ value: amt }("");
        require(sent, "Payment failed");
        emit PaymentTransferred(who, amt);
        emit StatusChangeApproved(pid, r.from, to, msg.sender);
    }
}
