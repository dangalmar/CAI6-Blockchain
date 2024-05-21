import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class VickreyAuction {
    private String owner;
    private long endDate;
    private double marketPrice;
    private boolean auctionEnded;
    private boolean itemDelivered;

    private class Bid {
        String bidder;
        double amount;

        Bid(String bidder, double amount) {
            this.bidder = bidder;
            this.amount = amount;
        }
    }

    private List<Bid> bids;
    private Map<String, Double> deposits;
    private Bid lowestBid;
    private Bid secondLowestBid;

    public VickreyAuction(String owner, long endDate, double marketPrice) {
        this.owner = owner;
        this.endDate = endDate;
        this.marketPrice = marketPrice;
        this.auctionEnded = false;
        this.itemDelivered = false;
        this.bids = new ArrayList<>();
        this.deposits = new HashMap<>();
        this.lowestBid = new Bid("", Double.MAX_VALUE);
        this.secondLowestBid = new Bid("", Double.MAX_VALUE);
    }

    public void placeBid(String bidder, double amount) {
        if (System.currentTimeMillis() > endDate || auctionEnded) {
            throw new IllegalStateException("Auction has ended or reached maximum bidders");
        }
        if (amount <= 0 || amount >= marketPrice) {
            throw new IllegalArgumentException("Bid must be positive and less than market price");
        }
        if (deposits.containsKey(bidder)) {
            throw new IllegalStateException("You have already placed a bid");
        }

        deposits.put(bidder, amount * 0.1);
        bids.add(new Bid(bidder, amount));

        if (amount < lowestBid.amount) {
            secondLowestBid = lowestBid;
            lowestBid = new Bid(bidder, amount);
        } else if (amount < secondLowestBid.amount) {
            secondLowestBid = new Bid(bidder, amount);
        }
    }

    public void endAuction() {
        if (System.currentTimeMillis() < endDate && bids.size() < 30) {
            throw new IllegalStateException("Auction is still ongoing");
        }
        auctionEnded = true;

        if (bids.size() == 1) {
            secondLowestBid = lowestBid;
        }

        System.out.println("Auction ended. Lowest bidder: " + lowestBid.bidder + ", Amount: " + secondLowestBid.amount);

        for (Bid bid : bids) {
            if (!bid.bidder.equals(lowestBid.bidder)) {
                double refundAmount = deposits.get(bid.bidder);
                deposits.put(bid.bidder, 0.0);
                System.out.println("Refunding " + bid.bidder + ": " + refundAmount);
            }
        }
    }

    public void deliverItem(String bidder) {
        if (!auctionEnded) {
            throw new IllegalStateException("Auction has not ended yet");
        }
        if (!bidder.equals(lowestBid.bidder)) {
            throw new IllegalStateException("Only the lowest bidder can deliver the item");
        }
        if (itemDelivered) {
            throw new IllegalStateException("Item has already been delivered");
        }
        itemDelivered = true;

        double paymentAmount = bids.size() == 1 ? lowestBid.amount : secondLowestBid.amount;
        System.out.println("Transferring to owner: " + paymentAmount);

        double refundAmount = deposits.get(lowestBid.bidder);
        deposits.put(lowestBid.bidder, 0.0);
        System.out.println("Refunding lowest bidder: " + refundAmount);
    }

    public static void main(String[] args) {
        VickreyAuction auction = new VickreyAuction("Owner", System.currentTimeMillis() + 60000, 3000);

        auction.placeBid("Bidder1", 2750);
        auction.placeBid("Bidder2", 2500);
        auction.placeBid("Bidder3", 3020);

        try {
            Thread.sleep(61000); // Wait for auction to end
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        auction.endAuction();
        auction.deliverItem("Bidder2");
    }
}
