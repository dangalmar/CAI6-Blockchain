// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract VickreyAuction {
    address payable public immutable owner;
    uint256 public immutable endDate;
    uint256 public immutable marketPrice;
    uint256 public constant minBidIncrement = 10; // 10% of the bid
    uint256 public constant maxBidders = 30;
    
    struct Bid {
        address payable bidder;
        uint256 amount;
        bool hasBidded;
    }

    mapping(address => Bid) public bids;
    address[] public bidders;
    address payable public lowestBidder;
    address public secondLowestBidder;
    uint256 public lowestBid;
    uint256 public secondLowestBid;
    mapping(address => uint256) public pendingReturns;

    bool public auctionEnded;
    bool public itemDelivered;
    
    event AuctionStarted(uint256 endDate);
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address lowestBidder, uint256 secondLowestBid);
    event ItemDelivered(address indexed bidder);
    event RefundIssued(address indexed bidder, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier auctionOngoing() {
        require(block.timestamp < endDate && bidders.length < maxBidders, "Auction has ended or reached maximum bidders");
        _;
    }

    modifier auctionEndedModifier() {
        require(block.timestamp >= endDate || bidders.length >= maxBidders, "Auction is still ongoing");
        _;
    }

    constructor(uint256 _endDate, uint256 _marketPrice) {
        require(_endDate > block.timestamp, "End date must be in the future");
        owner = payable(msg.sender);
        endDate = _endDate;
        marketPrice = _marketPrice;
        lowestBid = type(uint256).max;
        secondLowestBid = type(uint256).max;
        auctionEnded = false;
        itemDelivered = false;
        emit AuctionStarted(endDate);
    }

    function placeBid() external payable auctionOngoing {
        require(msg.value > 0 && msg.value < marketPrice, "Bid must be positive and less than market price");
        require(!bids[msg.sender].hasBidded, "You have already placed a bid");

        bids[msg.sender] = Bid(payable(msg.sender), msg.value, true);
        bidders.push(msg.sender);

        if (msg.value < lowestBid) {
            secondLowestBid = lowestBid;
            secondLowestBidder = lowestBidder;
            lowestBid = msg.value;
            lowestBidder = payable(msg.sender);
        } else if (msg.value < secondLowestBid) {
            secondLowestBid = msg.value;
            secondLowestBidder = msg.sender;
        }

        emit BidPlaced(msg.sender, msg.value);
    }

    function endAuction() external onlyOwner auctionEndedModifier {
        require(!auctionEnded, "Auction has already ended");
        auctionEnded = true;

        if (bidders.length == 1) {
            secondLowestBid = lowestBid;
        }

        emit AuctionEnded(lowestBidder, secondLowestBid);

        uint256 length = bidders.length;
        for (uint256 i = 0; i < length; i++) {
            if (bidders[i] != lowestBidder) {
                uint256 refundAmount = bids[bidders[i]].amount;
                bids[bidders[i]].amount = 0;
                pendingReturns[bidders[i]] += refundAmount;
                emit RefundIssued(bidders[i], refundAmount);
            }
        }
    }

    function withdrawRefund() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function deliverItem() external auctionEndedModifier {
        require(msg.sender == lowestBidder, "Only the lowest bidder can deliver the item");
        require(!itemDelivered, "Item has already been delivered");
        itemDelivered = true;

        uint256 paymentAmount = secondLowestBid;
        if (bidders.length == 1) {
            paymentAmount = lowestBid;
        }
        owner.transfer(paymentAmount);
        emit ItemDelivered(lowestBidder);

        // Effect done before transfer
        uint256 refundAmount = lowestBid;
        lowestBid = 0;  // Prevent re-entrancy
        lowestBidder.transfer(refundAmount);
    }

    function refundBidders() external auctionEndedModifier {
        require(auctionEnded, "Auction has not ended yet");
        require(itemDelivered, "Item has not been delivered yet");

        uint256 length = bidders.length;
        for (uint256 i = 0; i < length; i++) {
            if (bidders[i] != lowestBidder) {
                uint256 refundAmount = bids[bidders[i]].amount;
                bids[bidders[i]].amount = 0;
                pendingReturns[bidders[i]] += refundAmount;
                emit RefundIssued(bidders[i], refundAmount);
            }
        }
    }
}
