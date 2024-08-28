// EA Definitions
enum TradingMode {
    ONE_WAY,
    TWO_WAYS
};

const int NO_ORDER = -1;

class ExecutedOrder {
private:
    int OrderType;
    bool StopLossHit;
    double TakeProfit;
    double StopLoss;
    double OrderLots;

public:
    // Constructor with default values
    ExecutedOrder() {
        resetProperties();
    }

    // GETTERS
    int getOrderType() const { return OrderType; }
    bool getStopLossHit() const { return StopLossHit; }
    double getTP() const { return TakeProfit; }
    double getSL() const { return StopLoss; }
    double getLotSize() const { return OrderLots; }

    // SETTERS
    void setOrderType(int type) { OrderType = type; }
    void setStopLossHit(bool slHit) { StopLossHit = slHit; }
    void setTP(double tp) { TakeProfit = tp; }
    void setSL(double sl) { StopLoss = sl; }
    void setLotSize(double lots) { OrderLots = lots; }

    // RESET
    void resetProperties() {
        OrderType = NO_ORDER;
        StopLossHit = false;
        TakeProfit = 0.0;
        StopLoss = 0.0;
        OrderLots = 0.0;
    }
};

// EA Inputs
input TradingMode tradingMode = TWO_WAYS;
input int ADXPeriod = 14;
input int ADXThreshold = 25;

input double baseLot = 0.01;
input double targetTP = 4.5;
input double targetSL = 3.0;
input double multiplier = 2.0;

// EA Global variables
ExecutedOrder executedOrder;
datetime lastProcessedTime = 0;
int magicNumber = 123456; // Example initialization

// EA Initialization
int OnInit() {
    return INIT_SUCCEEDED;
}

// EA Deinitialization
void OnDeinit(const int reason) {
    Print("EA de-initialized.");
}

// EA Tick Event
void OnTick() {
    CheckingOrderStatus();
    // Ensure that we only process once per bar
    if (Time[0] <= lastProcessedTime) {
        return;
    }

    OrderProcessing();
    // Update the last processed time to the current bar time
    lastProcessedTime = Time[0];
}

void OrderProcessing() {
    if (OrdersTotal() > 0) {
        return;
    }

    // Get current ADX, DMI values
    double adxVal = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
    double plusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 0);
    double minusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 0);

    // Get previous ADX
    double preAdxVal = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);

    int lastOrderType = executedOrder.getOrderType();
    double lastOrderLots = executedOrder.getLotSize();
    double orderLots = (lastOrderLots == 0.0) ? baseLot : lastOrderLots * multiplier;

    if (isBuyEntry(adxVal, preAdxVal, plusDMI, minusDMI)) {
        if (tradingMode == TWO_WAYS || (tradingMode == ONE_WAY && (lastOrderType == OP_BUY || lastOrderType == NO_ORDER))) {
            double buyPrice = Ask;
            
            OpenOrder(
                OP_BUY, 
                orderLots, 
                buyPrice, 
                buyPrice - targetSL, 
                buyPrice + targetTP, 
                "Buy with lots: " + DoubleToString(orderLots)
            );
            
            // Update executed order
            executedOrder.setOrderType(OP_BUY);
            executedOrder.setTP(buyPrice + targetTP);
            executedOrder.setSL(buyPrice - targetSL);
            executedOrder.setStopLossHit(false);
            executedOrder.setLotSize(orderLots);
        }
    } else if (isSellEntry(adxVal, preAdxVal, plusDMI, minusDMI)) {
        if (tradingMode == TWO_WAYS || (tradingMode == ONE_WAY && (lastOrderType == OP_SELL || lastOrderType == NO_ORDER))) {
            double sellPrice = Bid;
            
            OpenOrder(
                OP_SELL, 
                orderLots, 
                sellPrice, 
                sellPrice + targetSL, 
                sellPrice - targetTP, 
                "Sell with lots: " + DoubleToString(orderLots)
            );

            // Update executed order
            executedOrder.setOrderType(OP_SELL);
            executedOrder.setTP(sellPrice - targetTP);
            executedOrder.setSL(sellPrice + targetSL);
            executedOrder.setStopLossHit(false);
            executedOrder.setLotSize(orderLots);
        }
    }
}

void CheckingOrderStatus() {
    int lastOrderType = executedOrder.getOrderType();
    if (lastOrderType == NO_ORDER || executedOrder.getStopLossHit()) {
        return;
    }

    double lastOrderTP = executedOrder.getTP();
    double lastOrderSL = executedOrder.getSL();    

    if ((lastOrderType == OP_BUY && Ask >= lastOrderTP) || (lastOrderType == OP_SELL && Bid <= lastOrderTP)) {
        executedOrder.resetProperties();
    } else if ((lastOrderType == OP_BUY && Ask <= lastOrderSL) || (lastOrderType == OP_SELL && Bid >= lastOrderSL)) {
        executedOrder.setStopLossHit(true);
    }
}

// Helper function to determine sell entry
bool isSellEntry(double adx, double preAdx, double plusDMI, double minusDMI) {
    return (preAdx < ADXThreshold && adx > ADXThreshold && minusDMI > plusDMI);
}

// Helper function to determine buy entry
bool isBuyEntry(double adx, double preAdx, double plusDMI, double minusDMI) {
    return (preAdx < ADXThreshold && adx > ADXThreshold && minusDMI < plusDMI);
}

// Function to open an order
void OpenOrder(int orderType, double lotSize, double price, double sl, double tp, string comment) {
    Print(
        "Attempting to open order. Type: ", orderType, 
        ", Lot Size: ", lotSize, 
        ", Price: ", price, 
        ", SL: ", sl, 
        ", TP: ", tp, 
        ", Magic Number: ", magicNumber, 
        ", Comment: ", comment);

    int ticket = OrderSend(Symbol(), orderType, lotSize, price, 2, sl, tp, comment, magicNumber, 0, clrNONE);
    if (ticket < 0) {
        Print("Error opening order: ", GetLastError());
    } else {
        Print("Order opened successfully. Ticket: ", ticket);
    }
}
