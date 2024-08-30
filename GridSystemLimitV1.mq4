// Define input parameters
input double GridSpacing = 600;  // Distance between grid levels in points
input double LotSize = 0.1;      // Lot size for each order
input double TakeProfit = 600;   // Take profit in points
input double StopLoss = 600;     // Stop loss in points
input int numberToHedge = 2;
input double percentEquity = 0.6;

double currentPrice;

datetime lastBarTime = 0;

bool orderClosed = false; // Flag to track if an order was closed

// Initialize flags to track existing orders
bool buyLimitExists = false;
bool sellLimitExists = false;

bool hedgingFlag = false;

// Main trading logic
void OnTick() {
    // Get the current bid price
    currentPrice = MarketInfo(Symbol(), MODE_BID);
    datetime currentBarTime = iTime(NULL, 0, 0);

    if (hedgingFlag) {
        Comment("We are hedging now");
    } else {
        Comment("We are not hedging");
    }

    if (currentBarTime != lastBarTime) {
        checkDoubleOrder();

        // Define the price levels for Buy Limit and Sell Limit
        double buyLimitLevel = currentPrice - GridSpacing * Point;
        double sellLimitLevel = currentPrice + GridSpacing * Point;

        buyLimitExists = false;
        sellLimitExists = false;

        // Check for existing Buy Limit and Sell Limit orders
        for (int i = 0; i < OrdersTotal(); i++) {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                if (OrderSymbol() == Symbol()) {
                    // Check for Buy Limit order
                    if (OrderType() == OP_BUYLIMIT) {
                        buyLimitExists = true;
                        // Move Buy Limit order if it is more than GridSpacing points away
                        if (MathAbs(currentPrice - OrderOpenPrice()) > GridSpacing * Point) {
                            double newBuyLimitLevel = currentPrice - GridSpacing * Point;
                            double takeProfit = newBuyLimitLevel + TakeProfit * Point;
                            double stopLoss = 0;

                            if (OrderModify(OrderTicket(), newBuyLimitLevel, stopLoss, takeProfit, 0, Blue)) {
                                Print("Buy Limit order moved to ", newBuyLimitLevel);
                            } else {
                                Print("Error modifying Buy Limit order: ", GetLastError());
                            }
                        }
                    }
                    // Check for Sell Limit order
                    if (OrderType() == OP_SELLLIMIT) {
                        sellLimitExists = true;
                        // Move Sell Limit order if it is more than GridSpacing points away
                        if (MathAbs(currentPrice - OrderOpenPrice()) > GridSpacing * Point) {
                            double newSellLimitLevel = currentPrice + GridSpacing * Point;
                            double takeProfit2 = newSellLimitLevel - TakeProfit * Point;
                            double stopLoss2 = 0;

                            if (OrderModify(OrderTicket(), newSellLimitLevel, stopLoss2, takeProfit2, 0, Red)) {
                                Print("Sell Limit order moved to ", newSellLimitLevel);
                            } else {
                                Print("Error modifying Sell Limit order: ", GetLastError());
                            }
                        }
                    }
                }
            }
        }

        // If no Buy Limit order exists, create one
        if (!buyLimitExists) {
            double takeProfit3 = buyLimitLevel + TakeProfit * Point;
            double stopLoss3 = 0;
            int buyLimitTicket = OrderSend(Symbol(), OP_BUYLIMIT, LotSize, buyLimitLevel, 3, 
                                           stopLoss3, takeProfit3, 
                                           "Grid Buy Limit", 0, 0, Blue);
            if (buyLimitTicket < 0) {
                Print("Error creating Buy Limit order: ", GetLastError());
            }
        }

        // If no Sell Limit order exists, create one
        if (!sellLimitExists) {
            double takeProfit4 = sellLimitLevel - TakeProfit * Point;
            double stopLoss4 = 0;
            int sellLimitTicket = OrderSend(Symbol(), OP_SELLLIMIT, LotSize, sellLimitLevel, 3, 
                                            stopLoss4, takeProfit4, 
                                            "Grid Sell Limit", 0, 0, Red);
            if (sellLimitTicket < 0) {
                Print("Error creating Sell Limit order: ", GetLastError());
            }
        }

        lastBarTime = currentBarTime;
    }

    if (hedgingFlag) {
        checkAndClosePositionsIfNoLoss();
    }
}

bool checkDoubleOrder() {
    int count_buy = 0;
    int count_sell = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_SELL) {
                count_sell += 1;
            }
            if (OrderType() == OP_BUY) {
                count_buy += 1;
            }
        }
    }

    if (count_buy >= numberToHedge || count_sell >= numberToHedge) {
        hedgingFlag = true;
    }
}

double calculateTotalLoss() {
    double profit = 0;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_SELL || OrderType() == OP_BUY) {
                profit += OrderProfit();
            }
        }
    }

    return profit;
}

void checkAndClosePositionsIfNoLoss() {
    // double totalLoss = calculateTotalLoss();

    double equity = AccountEquity();
    double balance = AccountBalance();

    if (balance / equity >= percentEquity) {
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

// void checkDistanceAvaialable(double openPrice) {
    
//     for (int i = 0; i < OrdersTotal(); i++) {
//         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
//             if (OrderType() == OP_SELL || OrderType() == OP_BUY) {
//                 profit += OrderProfit();
//             }
//         }
//     }
// }
