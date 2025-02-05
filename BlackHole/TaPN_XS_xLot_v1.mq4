// EA Definitions
enum TradingMode {
    ONE_WAY,
    TWO_WAYS
};

enum Strategy {
    ADX_DMI
};

const int NO_ORDER = -1;

class ExecutedOrder {
private:
    int orderType;
    bool stopLossHit;
    double takeProfit;
    double stopLoss;
    double orderLots;

public:
    // Constructor with default values
    ExecutedOrder() {
        resetProperties();
    }

    // GETTERS
    int getOrderType() const { return orderType; }
    bool getStopLossHit() const { return stopLossHit; }
    double getTakeProfit() const { return takeProfit; }
    double getStopLoss() const { return stopLoss; }
    double getLotSize() const { return orderLots; }

    // SETTERS
    void setOrderType(int type) { orderType = type; }
    void setStopLossHit(bool slHit) { stopLossHit = slHit; }
    void setTakeProfit(double tp) { takeProfit = tp; }
    void setStopLoss(double sl) { stopLoss = sl; }
    void setLotSize(double lots) { orderLots = lots; }

    // RESET
    void resetProperties() {
        orderType = NO_ORDER;
        stopLossHit = false;
        takeProfit = 0.0;
        stopLoss = 0.0;
        orderLots = 0.0;
    }
};

// EA Inputs
input TradingMode tradingMode = TWO_WAYS;
input Strategy strategy = ADX_DMI;
input int ADXPeriod = 14;
input int ADXThreshold = 30;
input int ADXDiff = 10;

input double baseLot = 0.01;
input double targetTakeProfit = 7.5;
input double targetStopLoss = 5.0;
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

    TradingManager();
    // Update the last processed time to the current bar time
    lastProcessedTime = Time[0];
}

void TradingManager() {
    if (OrdersTotal() > 0) {
        return;
    }
    
    switch (strategy) {
    case ADX_DMI: 
    default:
        AdxDMIOrderProcessing();
        break;
    }
}

void AdxDMIOrderProcessing() {
    // Get current ADX, DMI values
    double adxValue = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
    double plusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 0);
    double minusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 0);

    // Get previous ADX
    double prevAdxValue = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 2);

    double orderLots = (executedOrder.getLotSize() == 0.0) ? baseLot : executedOrder.getLotSize() * multiplier;

    if (isADMIBuyEntry(adxValue, prevAdxValue, plusDMI, minusDMI)) {
        executeBuyOrder(orderLots);
    } else if (isADMISellEntry(adxValue, prevAdxValue, plusDMI, minusDMI)) {
        executeSellOrder(orderLots);
    }
}

void CheckingOrderStatus() {
    if (executedOrder.getOrderType() == NO_ORDER || executedOrder.getStopLossHit()) {
        return;
    }

    double lastOrderTP = executedOrder.getTakeProfit();
    double lastOrderSL = executedOrder.getStopLoss();    

    if ((executedOrder.getOrderType() == OP_BUY && Ask >= lastOrderTP) || (executedOrder.getOrderType() == OP_SELL && Bid <= lastOrderTP)) {
        executedOrder.resetProperties();
    } else if ((executedOrder.getOrderType() == OP_BUY && Ask <= lastOrderSL) || (executedOrder.getOrderType() == OP_SELL && Bid >= lastOrderSL)) {
        executedOrder.setStopLossHit(true);
    }
}

void executeBuyOrder(double orderLots) {
    if (tradingMode == TWO_WAYS || (tradingMode == ONE_WAY && (executedOrder.getOrderType() == OP_BUY || executedOrder.getOrderType() == NO_ORDER))) {
        double buyPrice = Ask;
        
        OpenOrder(OP_BUY, orderLots, buyPrice, buyPrice - targetStopLoss, buyPrice + targetTakeProfit, "Buy with lots: " + DoubleToString(orderLots));

        // Update executed order
        executedOrder.setOrderType(OP_BUY);
        executedOrder.setTakeProfit(buyPrice + targetTakeProfit);
        executedOrder.setStopLoss(buyPrice - targetStopLoss);
        executedOrder.setStopLossHit(false);
        executedOrder.setLotSize(orderLots);
    }
}

void executeSellOrder(double orderLots) {
    if (tradingMode == TWO_WAYS || (tradingMode == ONE_WAY && (executedOrder.getOrderType() == OP_SELL || executedOrder.getOrderType() == NO_ORDER))) {
        double sellPrice = Bid;
        
        OpenOrder(OP_SELL, orderLots, sellPrice, sellPrice + targetStopLoss, sellPrice - targetTakeProfit, "Sell with lots: " + DoubleToString(orderLots));

        // Update executed order
        executedOrder.setOrderType(OP_SELL);
        executedOrder.setTakeProfit(sellPrice - targetTakeProfit);
        executedOrder.setStopLoss(sellPrice + targetStopLoss);
        executedOrder.setStopLossHit(false);
        executedOrder.setLotSize(orderLots);
    }
}


bool isADMIBuyEntry(double adx, double prevAdx, double plusDMI, double minusDMI) {
    return (prevAdx < ADXThreshold && adx > ADXThreshold && (plusDMI - minusDMI) >= ADXDiff);
}

bool isADMISellEntry(double adx, double prevAdx, double plusDMI, double minusDMI) {
    return (prevAdx < ADXThreshold && adx > ADXThreshold && (minusDMI - plusDMI) >= ADXDiff);
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
        ", Comment: ", comment
    );

    int ticket = OrderSend(Symbol(), orderType, lotSize, price, 2, sl, tp, comment, magicNumber, 0, clrNONE);
    if (ticket < 0) {
        Print("Error opening order: ", GetLastError());
    } else {
        Print("Order opened successfully. Ticket: ", ticket);
    }
}
