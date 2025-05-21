// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/SupplyChainToken.sol";

contract SupplyChainContract {
    SupplyChainToken sToken;
    address public tokenAddress;
    enum Role {
        ProductSeller,
        DistributorToWarehouse,
        Warehouse,
        DoorToDoorDelivery,
        ProductBuyer,
        PlatformOwner,
        None
    }
    enum Status {
        Available,
        ReadyToShip,
        Shipping,
        Shipped,
        ReadyForDelivery,
        OutForDelivery,
        Delivered
    }
    struct StatusChangeOperation {
        address requesterAddress;
        address approverAddress;
        bool requested;
        bool approved;
        Role requester;
        Role approver;
        PaymentOperation[] paymentOperations;
    }
    struct PaymentOperation {
        uint256 amount;
        Role payer;
        Role receiver;
        bool isPercentage;
    }
    mapping(uint256 => mapping(Status => mapping(Status => StatusChangeOperation)))
        public statusChangeOperations;

    struct User {
        address id;
        Role role;
        bool isApproved;
    }
    struct Product {
        uint256 id;
        string cid;
        Status status;
        uint256 price;
        address seller;
        address buyer;
        address distributor;
        address warehouse;
        address delivery;
    }
    mapping(address => User) public users;
    mapping(uint256 => Product) public products;

    address public owner;
    event EnrollRequested(address indexed u, Role r);
    event EnrollApproved(address indexed u, Role r, uint256 amount);
    event ProductUploaded(uint256 indexed id, string cid, uint256 price);
    event StatusChangeRequested(
        uint256 indexed id,
        Status from,
        Status to,
        address requester
    );
    event StatusChangeApproved(
        uint256 indexed id,
        Status from,
        Status to,
        address approver
    );
    event PaymentTransferred(address indexed to, uint256 amt);
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    modifier onlyApproved() {
        require(users[msg.sender].isApproved, "Not approved");
        _;
    }
    modifier notEnrolled() {
        require(!users[msg.sender].isApproved, "Already enrolled");
        _;
    }

    constructor() {
        sToken = new SupplyChainToken(0);
        tokenAddress = address(sToken);
        sToken.mint(msg.sender, 100000000);
        owner = msg.sender;
    }

    function requestEnrollment(Role r) external notEnrolled {
        users[msg.sender] = User(msg.sender, r, false);
        emit EnrollRequested(msg.sender, r);
    }

    function approveEnrollment(address u, uint256 amount) external onlyOwner {
        users[u].isApproved = true;
        sToken.mint(users[u].id, amount);
        emit EnrollApproved(u, users[u].role, amount);
    }

    function topUp(address u, uint256 amount) external onlyOwner {
        require(users[u].isApproved, "Not approved");
        sToken.mint(users[u].id, amount);
    }

    function _getProductId(string calldata cid)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(cid)));
    }

    function getProductId(string calldata cid) external pure returns (uint256) {
        return _getProductId(cid);
    }

    function uploadProduct(string calldata cid, uint256 price)
        external
        onlyApproved
    {
        require(users[msg.sender].role == Role.ProductSeller, "Only seller");
        uint256 pid = _getProductId(cid);
        products[_getProductId(cid)] = Product(
            pid,
            cid,
            Status.Available,
            price,
            msg.sender,
            address(0),
            address(0),
            address(0),
            address(0)
        );
        _configureDefaultPayments(pid);
        emit ProductUploaded(pid, cid, price);
    }

    function requestStatusChange(
        uint256 pid,
        Status from,
        Status to
    ) external onlyApproved {
        Product storage p = products[pid];
        _isEligibleForRequestingStatusChange(pid, from, to, p);
        StatusChangeOperation storage sco = statusChangeOperations[pid][from][
            to
        ];
        sco.requested = true;
        sco.requesterAddress = msg.sender;
        emit StatusChangeRequested(pid, p.status, to, msg.sender);
    }

    function approveStatusChange(
        uint256 pid,
        Status from,
        Status to
    ) external onlyApproved {
        Product storage p = products[pid];
        StatusChangeOperation storage sco = statusChangeOperations[pid][from][
            to
        ];
        _isEligibleForApprovalStatusChange(pid, from, to, p);
        _assignAddressesToProduct(pid, from, to, p);
        _proceessPayments(pid, from, to, p);
        sco.approved = true;
        sco.approverAddress = msg.sender;
        emit StatusChangeApproved(pid, from, to, msg.sender);
    }

    function _configureDefaultPayments(uint256 pid) internal {
        // Transition: Available -> ReadyToShip
        StatusChangeOperation storage sco1 = statusChangeOperations[pid][
            Status.Available
        ][Status.ReadyToShip];
        sco1.requesterAddress = address(0); // Placeholder, can be set dynamically
        sco1.approverAddress = address(0); // Placeholder
        sco1.requested = false;
        sco1.approved = false;
        sco1.requester = Role.ProductBuyer;
        sco1.approver = Role.ProductSeller;
        delete sco1.paymentOperations; // Ensures it's an empty array

        // Transition: ReadyToShip -> Shipping
        StatusChangeOperation storage sco2 = statusChangeOperations[pid][
            Status.ReadyToShip
        ][Status.Shipping];
        sco2.requesterAddress = address(0);
        sco2.approverAddress = address(0);
        sco2.requested = false;
        sco2.approved = false;
        sco2.requester = Role.DistributorToWarehouse;
        sco2.approver = Role.ProductSeller;
        delete sco2.paymentOperations;

        // Transition: Shipping -> Shipped
        StatusChangeOperation storage sco3 = statusChangeOperations[pid][
            Status.Shipping
        ][Status.Shipped];
        sco3.requesterAddress = address(0);
        sco3.approverAddress = address(0);
        sco3.requested = false;
        sco3.approved = false;
        sco3.requester = Role.DistributorToWarehouse;
        sco3.approver = Role.Warehouse;
        delete sco3.paymentOperations;
        sco3.paymentOperations.push(
            PaymentOperation(
                5,
                Role.PlatformOwner,
                Role.DistributorToWarehouse,
                false
            )
        );

        // Transition: Shipped -> ReadyForDelivery
        StatusChangeOperation storage sco4 = statusChangeOperations[pid][
            Status.Shipped
        ][Status.ReadyForDelivery];
        sco4.requesterAddress = address(0);
        sco4.approverAddress = address(0);
        sco4.requested = false;
        sco4.approved = false;
        sco4.requester = Role.DoorToDoorDelivery;
        sco4.approver = Role.Warehouse;
        delete sco4.paymentOperations;

        // Transition: ReadyForDelivery -> OutForDelivery
        StatusChangeOperation storage sco5 = statusChangeOperations[pid][
            Status.ReadyForDelivery
        ][Status.OutForDelivery];
        sco5.requesterAddress = address(0);
        sco5.approverAddress = address(0);
        sco5.requested = false;
        sco5.approved = false;
        sco5.requester = Role.DoorToDoorDelivery;
        sco5.approver = Role.Warehouse; // Note: Approver is Warehouse here
        delete sco5.paymentOperations;
        sco5.paymentOperations.push(
            PaymentOperation(5, Role.PlatformOwner, Role.Warehouse, false) // Payment to Warehouse from PlatformOwner
        );

        // Transition: OutForDelivery -> Delivered
        StatusChangeOperation storage sco6 = statusChangeOperations[pid][
            Status.OutForDelivery
        ][Status.Delivered];
        sco6.requesterAddress = address(0);
        sco6.approverAddress = address(0);
        sco6.requested = false;
        sco6.approved = false;
        sco6.requester = Role.DoorToDoorDelivery;
        sco6.approver = Role.ProductBuyer;
        delete sco6.paymentOperations;
        sco6.paymentOperations.push(
            PaymentOperation(100, Role.ProductBuyer, Role.ProductSeller, true)
        );
        sco6.paymentOperations.push(
            PaymentOperation(15, Role.ProductSeller, Role.PlatformOwner, true)
        );
        sco6.paymentOperations.push(
            PaymentOperation(
                5,
                Role.PlatformOwner,
                Role.DoorToDoorDelivery,
                false
            )
        );
    }

    function _isEligibleForRequestingStatusChange(
        uint256 pid,
        Status from,
        Status to,
        Product storage p
    ) internal view {
        require(
            !statusChangeOperations[pid][from][to].requested,
            "Already requested"
        );
        require(
            _checkPreRequisiteComplete(pid, from, to),
            "Previous stage of the supply chain not yet passed"
        );
        if (
            (from == Status.Available && to == Status.ReadyToShip) ||
            (from == Status.ReadyToShip && to == Status.Shipping) ||
            (from == Status.Shipped && to == Status.ReadyForDelivery)
        ) {
            require(
                statusChangeOperations[pid][from][to].requester ==
                    users[msg.sender].role,
                "Not a valid requester"
            );
        } else if (from == Status.Shipping && to == Status.Shipped) {
            require(
                statusChangeOperations[pid][from][to].requester ==
                    users[msg.sender].role &&
                    p.distributor == msg.sender,
                "Not a valid requester"
            );
        } else if (
            (from == Status.ReadyForDelivery && to == Status.OutForDelivery) ||
            (from == Status.OutForDelivery && to == Status.Delivered)
        ) {
            require(
                statusChangeOperations[pid][from][to].requester ==
                    users[msg.sender].role &&
                    p.delivery == msg.sender,
                "Not a valid requester"
            );
        } else {
            revert("Not a valid requester");
        }
    }

    function _checkPreRequisiteComplete(
        uint256 pid,
        Status from,
        Status to
    ) internal view returns (bool) {
        if (from == Status.Available && to == Status.ReadyToShip) {
            return true;
        } else if (from == Status.ReadyToShip && to == Status.Shipping) {
            return
                statusChangeOperations[pid][Status.Available][
                    Status.ReadyToShip
                ].approved;
        } else if (from == Status.Shipping && to == Status.Shipped) {
            return
                statusChangeOperations[pid][Status.ReadyToShip][
                    Status.Shipping
                ].approved;
        } else if (from == Status.Shipped && to == Status.ReadyForDelivery) {
            return
                statusChangeOperations[pid][Status.Shipping][Status.Shipped]
                    .approved;
        } else if (
            from == Status.ReadyForDelivery && to == Status.OutForDelivery
        ) {
            return
                statusChangeOperations[pid][Status.Shipped][
                    Status.ReadyForDelivery
                ].approved;
        } else if (from == Status.OutForDelivery && to == Status.Delivered) {
            return
                statusChangeOperations[pid][Status.ReadyForDelivery][
                    Status.OutForDelivery
                ].approved;
        } else {
            return false;
        }
    }

    function _isEligibleForApprovalStatusChange(
        uint256 pid,
        Status from,
        Status to,
        Product storage p
    ) internal view {
        require(
            !statusChangeOperations[pid][from][to].approved,
            "Already Approved"
        );
        require(
            statusChangeOperations[pid][from][to].requested,
            "Not requested yet"
        );
        if (
            (from == Status.Available && to == Status.ReadyToShip) ||
            (from == Status.ReadyToShip && to == Status.Shipping)
        ) {
            require(
                statusChangeOperations[pid][from][to].approver ==
                    users[msg.sender].role &&
                    p.seller == msg.sender,
                "Not a valid approver"
            );
        } else if (from == Status.Shipping && to == Status.Shipped) {
            require(
                statusChangeOperations[pid][from][to].approver ==
                    users[msg.sender].role,
                "Not a valid approver"
            );
        } else if (
            (from == Status.Shipped && to == Status.ReadyForDelivery) ||
            (from == Status.ReadyForDelivery && to == Status.OutForDelivery)
        ) {
            require(
                statusChangeOperations[pid][from][to].approver ==
                    users[msg.sender].role &&
                    p.warehouse == msg.sender,
                "Not a valid approver"
            );
        } else if (from == Status.OutForDelivery && to == Status.Delivered) {
            require(
                statusChangeOperations[pid][from][to].approver ==
                    users[msg.sender].role &&
                    p.buyer == msg.sender,
                "Not a valid approver"
            );
        } else {
            revert("Not a valid approver");
        }
    }

    function _assignAddressesToProduct(
        uint256 pid,
        Status from,
        Status to,
        Product storage p
    ) internal {
        StatusChangeOperation storage sco = statusChangeOperations[pid][from][
            to
        ];
        if (from == Status.Available && to == Status.ReadyToShip) {
            p.buyer = sco.requesterAddress;
        } else if (from == Status.ReadyToShip && to == Status.Shipping) {
            p.distributor = sco.requesterAddress;
        } else if (from == Status.Shipping && to == Status.Shipped) {
            p.warehouse = msg.sender;
        } else if (from == Status.Shipped && to == Status.ReadyForDelivery) {
            p.delivery = sco.requesterAddress;
        }
    }

    function _proceessPayments(
        uint256 pid,
        Status from,
        Status to,
        Product storage p
    ) internal {
        StatusChangeOperation storage sco = statusChangeOperations[pid][from][
            to
        ];
        for (uint256 i = 0; i < sco.paymentOperations.length; i++) {
            PaymentOperation storage po = sco.paymentOperations[i];
            uint256 paymentAmount = po.amount;
            if (po.isPercentage) {
                paymentAmount = (p.price * po.amount) / 100;
            }
            address payerAddress = _getAddressForRole(po.payer, p);
            address receiverAddress = _getAddressForRole(po.receiver, p);
            sToken.transferOfFunds(
                payerAddress,
                receiverAddress,
                paymentAmount
            );
        }
    }

    function _getAddressForRole(Role role, Product storage p)
        internal
        view
        returns (address)
    {
        if (role == Role.ProductSeller) return p.seller;
        if (role == Role.ProductBuyer) return p.buyer;
        if (role == Role.DistributorToWarehouse) return p.distributor;
        if (role == Role.Warehouse) return p.warehouse;
        if (role == Role.DoorToDoorDelivery) return p.delivery;
        if (role == Role.PlatformOwner) return owner; // Contract owner is platform owner
        return address(0);
    }
}
