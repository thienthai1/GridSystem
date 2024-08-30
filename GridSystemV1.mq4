// Define input parameters
input double GridSpacing = 600;  // Distance between grid levels in points
input double LotSize = 0.1;      // Lot size for each order
input double TakeProfit = 600;   // Take profit in points
input double StopLoss = 600;     // Stop loss in points

double currentPrice;

datetime lastBarTime = 0;

bool orderClosed = false; // Flag to track if an order was closed

// Initialize flags to track existing orders
bool buyStopExists = false;
bool sellStopExists = false;

bool hedgingFlag = false;

// Main trading logic
void OnTick() {
    // Get the current bid price
    currentPrice = MarketInfo(Symbol(), MODE_BID);
    datetime currentBarTime = iTime(NULL, 0, 0);

    if(hedgingFlag){
        Comment("We hedginh now");
    }else{
        Comment("We not hedging");
    }
    
    if (currentBarTime != lastBarTime) {
        checkdoubleOrder();

        // Define the price levels for Buy Stop and Sell Stop
        double buyStopLevel = currentPrice + GridSpacing * Point;
        double sellStopLevel = currentPrice - GridSpacing * Point;

        buyStopExists = false;
        sellStopExists = false;
        
        // Check for existing Buy Stop and Sell Stop orders
        for (int i = 0; i < OrdersTotal(); i++) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if (OrderSymbol() == Symbol()) {
                    // Check for Buy Stop order
                    if (OrderType() == OP_BUYSTOP) {
                        buyStopExists = true;
                        // Move Buy Stop order if it is more than 300 points away
                        if (MathAbs(currentPrice - OrderOpenPrice()) > GridSpacing * Point ) {
                            double newBuyStopLevel = currentPrice + GridSpacing * Point;

                            double takeProfit = newBuyStopLevel + TakeProfit * Point;

                            if (OrderModify(OrderTicket(), newBuyStopLevel, 0, takeProfit, 0, Blue)) {
                                Print("Buy Stop order moved to ", newBuyStopLevel);
                            } else {
                                Print("Error modifying Buy Stop order: ", GetLastError());
                            }
                        }
                    }
                    // Check for Sell Stop order
                    if (OrderType() == OP_SELLSTOP) {
                        sellStopExists = true;
                        // Move Sell Stop order if it is less than 300 points away
                        
                        if (MathAbs(currentPrice - OrderOpenPrice())  * Point < GridSpacing) {
                            double newSellStopLevel = currentPrice - GridSpacing * Point;

                            double takeProfit2 = newSellStopLevel - TakeProfit * Point;


                            if (OrderModify(OrderTicket(), newSellStopLevel, 0, takeProfit2, 0, Red)) {
                                Print("Sell Stop order moved to ", newSellStopLevel);
                            } else {
                                Print("Error modifying Sell Stop order: ", GetLastError());
                            }
                        }
                    }
                }
            }
        }

        // If no Buy Stop order exists, create one
        if (!buyStopExists) {
            double takeProfit3 = buyStopLevel + TakeProfit * Point;
            int buyStopTicket = OrderSend(Symbol(), OP_BUYSTOP, LotSize, buyStopLevel, 3, 
                                        0, 
                                        takeProfit3, 
                                        "Grid Buy Stop", 0, 0, Blue);
            if (buyStopTicket < 0) {
                Print("Error creating Buy Stop order: ", GetLastError());
            }
        }

        // If no Sell Stop order exists, create one
        if (!sellStopExists) {
            double takeProfit4 = sellStopLevel - TakeProfit * Point;
            int sellStopTicket = OrderSend(Symbol(), OP_SELLSTOP, LotSize, sellStopLevel, 3, 
                                        0, 
                                        sellStopLevel - TakeProfit * Point, 
                                        "Grid Sell Stop", 0, 0, Red);
            if (sellStopTicket < 0) {
                Print("Error creating Sell Stop order: ", GetLastError());
            }
        }

        lastBarTime = currentBarTime;
    }

    if(hedgingFlag){
        checkAndClosePositionsIfNoLoss();
    }

}

bool checkdoubleOrder(){
    int count_buy = 0;
    int count_sell = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {

            if(OrderType() == OP_SELL){
                count_sell += 1;
            }

            if(OrderType() == OP_BUY){
                count_buy += 1;
            }

        }
    }

    if(count_buy >= 2 || count_sell >= 2){
        hedgingFlag = true;
    }

}

double calculateTotalLoss() {
    double profit = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {

            if(OrderType() == OP_SELL || OrderType() == OP_BUY){
                profit += OrderProfit();
            }

        }
    }

    return profit;
}

void checkAndClosePositionsIfNoLoss() {
    double totalLoss = calculateTotalLoss();

    if (totalLoss >= 0) {
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                // Close Buy and Sell orders
                if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
                    if (OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, Violet)) {
                        Print("Order closed: ", OrderTicket());
                    } else {
                        Print("Error closing order: ", GetLastError());
                    }
                }
            }
        }
        hedgingFlag = false;
    }
}
