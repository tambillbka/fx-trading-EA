// EA Definitions
enum TradingMode {
    ONE_WAY,
    TWO_WAYS
};

enum Strategies {
    ADX_DMI
};

const int NO_ORDER = -1;
const double SL_HIT = -1.0;

class ExecutedOrder {
private:
    int orderType;
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
    double getTakeProfit() const { return takeProfit; }
    double getStopLoss() const { return stopLoss; }
    double getLotSize() const { return orderLots; }

    // SETTERS
    void setOrderType(int type) { orderType = type; }
    void setTakeProfit(double tp) { takeProfit = tp; }
    void setStopLoss(double sl) { stopLoss = sl; }
    void setLotSize(double lots) { orderLots = lots; }

    // RESET
    void resetProperties() {
        orderType = NO_ORDER;
        takeProfit = 0.0;
        stopLoss = 0.0;
        orderLots = 0.0;
    }
};

// EA Inputs
TradingMode tradingMode = TWO_WAYS;
input Strategies Strategy = ADX_DMI;

input string ADX_DMI_Strategy = "=== ADX DMI Settings ===";
input int ADXPeriod = 14;
input int ADXThreshold = 28;
input int DMIDiff = 15;

input string Risk_Management = "=== Risk Management Settings ===";
input double BaseLot = 0.01;
input int TakeProfit = 600;
input int StopLoss = 400;
input double Multiplier = 2.0;
input double MaxLots = 3.0;

// EA Global variables
ExecutedOrder executedOrder;
datetime lastProcessedTime = 0;
int magicNumber = 123456; // Example initialization

// EA Initialization
int OnInit() {
    executedOrder.resetProperties();

    // Set chart type to Candlestick
    ChartSetInteger(0, CHART_MODE, CHART_CANDLE);
    ChartSetInteger(0, CHART_SCALE, 3);

    // Set chart colors based on your template configuration
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, 3943424);     // background_color=3943424 (dark)
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, 16777215);    // foreground_color=16777215 (white)
    ChartSetInteger(0, CHART_COLOR_CHART_UP, 16776960);         // barup_color=65407 (green)
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, 11823615);        // bardown_color=9639167 (dark red)
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, 16776960);      // bullcandle_color=65280 (green)
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, 11823615);    // bearcandle_color=3943424 (dark)
    ChartSetInteger(0, CHART_COLOR_CHART_LINE, 16776960);           // chartline_color=65280 (lime)
    ChartSetInteger(0, CHART_COLOR_VOLUME, 10526303);        // volumes_color=10526303 (grey)
    ChartSetInteger(0, CHART_COLOR_ASK, 255);                // askline_color=255 (blue)
    ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, 255);         // stops_color=255 (blue)
    ChartRedraw();  // Redraw the chart to apply the changes immediately
    return INIT_SUCCEEDED;
}

// EA Deinitialization
void OnDeinit(const int reason) {
    executedOrder.resetProperties();
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
    
    AdxDMIOrderProcessing();
}

//-------------------------------------------------------------
//==================== ADX Strategy ===========================
//-------------------------------------------------------------
void AdxDMIOrderProcessing() {
    // Get current ADX, DMI values
    double adxValue = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
    double plusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_PLUSDI, 0);
    double minusDMI = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MINUSDI, 0);

    // Get previous ADX
    double prevAdxValue = iADX(Symbol(), 0, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 2);

    double orderLots = (executedOrder.getLotSize() == 0.0) 
                        ? BaseLot 
                        : executedOrder.getLotSize() * Multiplier;

    if (isADMIBuyEntry(adxValue, prevAdxValue, plusDMI, minusDMI)) {
        executeBuyOrder(orderLots);
    } 
    else if (isADMISellEntry(adxValue, prevAdxValue, plusDMI, minusDMI)) {
        executeSellOrder(orderLots);
    }
}

bool isADMIBuyEntry(double adx, double prevAdx, double plusDMI, double minusDMI) {
    return (prevAdx < ADXThreshold && adx > ADXThreshold && (plusDMI - minusDMI) >= DMIDiff);
}

bool isADMISellEntry(double adx, double prevAdx, double plusDMI, double minusDMI) {
    return (prevAdx < ADXThreshold && adx > ADXThreshold && (minusDMI - plusDMI) >= DMIDiff);
}

//-------------------------------------------------------------

void CheckingOrderStatus() {
    double lastOrderSL = executedOrder.getStopLoss();
    if (executedOrder.getOrderType() == NO_ORDER || lastOrderSL < 0) {
        return;
    }

    double lastOrderTP = executedOrder.getTakeProfit();
    double lastOrderLots = executedOrder.getLotSize();

    if ((executedOrder.getOrderType() == OP_BUY && Ask >= lastOrderTP) || 
        (executedOrder.getOrderType() == OP_SELL && Bid <= lastOrderTP)) {
        executedOrder.resetProperties();
    } 
    else if ((executedOrder.getOrderType() == OP_BUY && Ask <= lastOrderSL) || 
             (executedOrder.getOrderType() == OP_SELL && Bid >= lastOrderSL)) {
        if (MaxLots > 0 && (lastOrderLots * Multiplier) > MaxLots) {
            executedOrder.resetProperties();
        } else {
            executedOrder.setStopLoss(SL_HIT);
        }
    }
}

void executeBuyOrder(double orderLots) {
    double buyPrice = Ask;
    double buyTP = Ask + (TakeProfit * Point * 10);
    double buySL = Ask - (StopLoss * Point * 10);
        
    bool openOrderSuccess = OpenOrder(
        OP_BUY, orderLots, buyPrice, buySL, buyTP, 
        "Buy with lots: " + DoubleToString(orderLots)
    );

    if (openOrderSuccess) {
        // Update executed order
        executedOrder.setOrderType(OP_BUY);
        executedOrder.setTakeProfit(buyTP);
        executedOrder.setStopLoss(buySL);
        executedOrder.setLotSize(orderLots);
    }
}

void executeSellOrder(double orderLots) {
    double sellPrice = Bid;
    double sellTP = Bid - (TakeProfit * Point * 10);
    double sellSL = Bid + (StopLoss * Point * 10);
        
    bool openOrderSuccess = OpenOrder(
        OP_SELL, orderLots, sellPrice, sellSL, sellTP, 
        "Sell with lots: " + DoubleToString(orderLots)
    );

    if (openOrderSuccess) {
        // Update executed order
        executedOrder.setOrderType(OP_SELL);
        executedOrder.setTakeProfit(sellTP);
        executedOrder.setStopLoss(sellSL);
        executedOrder.setLotSize(orderLots);
    }
}

// Function to open an order
bool OpenOrder(int orderType, double lotSize, double price, double sl, double tp, string comment) {
    Print("Attempting to open order. Type: ", orderType, 
          ", Lot Size: ", lotSize, ", Price: ", price, 
          ", SL: ", sl, ", TP: ", tp, ", Magic Number: ", magicNumber, 
          ", Comment: ", comment);

    int ticket = OrderSend(Symbol(), orderType, lotSize, price, 2, sl, tp, comment, magicNumber, 0, clrNONE);
    
    if (ticket < 0) {
        Print("Error opening order: ", GetLastError());
        return false;
    } else {
        Print("Order opened successfully. Ticket: ", ticket);
        return true;
    }
}
