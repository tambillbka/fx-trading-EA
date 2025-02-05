// Input parameters
input double baseLot = 0.01;
input double targetProfit = 1.0;

input bool excludeTime = false;
input int excludeStartTime = 600;
input int excludeEndTime = 2200;
input double maxAcceptedSpread = 0.3;

// ATR threshold for trading
input double ATRThreshold = 0.68;

// Processing variables
double firstBuyEntry = 0.0;
double firstSellEntry = 0.0;

// EA Common value
int fibonancies[] = {1, 2, 3, 5, 8, 13, 21, 34, 55, 89};

// Distances and lots
double DCA_Distances_Base = 0.0;
input double DCA_Distances_1 = 0.5;
input double DCA_Distances_2 = 1.0;
input double DCA_Distances_3 = 1.6;
input double DCA_Distances_4 = 2.2;
input double DCA_Distances_5 = 2.8;
input double DCA_Distances_6 = 3.5;
input double DCA_Distances_7 = 4.5;
input double DCA_Distances_8 = 6.0;
input double DCA_Distances_9 = 10.0;
double DCA_Distances[10];
double DCA_Lots[10];

int OnInit()
{
    // Initialize lot sizes based on Fibonacci sequence
    for (int i = 0; i < ArraySize(fibonancies); i++) {
        DCA_Lots[i] = fibonancies[i] * baseLot;
    }

    // Init distances
    DCA_Distances[0] = DCA_Distances_Base;
    DCA_Distances[1] = DCA_Distances_1;
    DCA_Distances[2] = DCA_Distances_2;
    DCA_Distances[3] = DCA_Distances_3;
    DCA_Distances[4] = DCA_Distances_4;
    DCA_Distances[5] = DCA_Distances_5;
    DCA_Distances[6] = DCA_Distances_6;
    DCA_Distances[7] = DCA_Distances_7;
    DCA_Distances[8] = DCA_Distances_8;
    DCA_Distances[9] = DCA_Distances_9;
    Print("EA initialized successfully.");
    return(INIT_SUCCEEDED);
}

void OnTick()
{
    // Calculate ATR (14-period by default)
    double currentATR = iATR(Symbol(), PERIOD_M1, 14, 0);

    int totalOrders = OrdersTotal();
    
    if (totalOrders == 0) {
        OpenBuySellPair(currentATR);
        return;
    } else {
        double curBuyPrice = Ask;
        double curSellPrice = Bid;

        int totalBuyOrders = CountOrders(OP_BUY);
        int totalSellOrders = CountOrders(OP_SELL);

        // Check if target profit is reached
        if (AccountProfit() >= targetProfit)
        {
            CloseAllOrders();
            ResetAll();
            return;
        }

        // Waiting for ATR down
        if (currentATR > ATRThreshold) {
            return;
        }

        // Logic to open new buy orders
        if (totalBuyOrders < 10)
        {
            double targetBuyPrice = firstBuyEntry - DCA_Distances[totalBuyOrders];
            if (curBuyPrice <= targetBuyPrice)
            {
                OpenOrder(OP_BUY, DCA_Lots[totalBuyOrders], curBuyPrice, 0, 0, "DCA_Buy_" + IntegerToString(totalBuyOrders + 1));
            }
        }

        // Logic to open new sell orders
        if (totalSellOrders < 10)
        {
            double targetSellPrice = firstSellEntry + DCA_Distances[totalSellOrders];
            if (curSellPrice >= targetSellPrice)
            {
                OpenOrder(OP_SELL, DCA_Lots[totalSellOrders], curSellPrice, 0, 0, "DCA_Sell_" + IntegerToString(totalSellOrders + 1));
            }
        }
    }
}

void OpenBuySellPair(double currentATR)
{
    // Waiting for ATR down
    if (currentATR > ATRThreshold) {
        return;
    }
    // Get current time in HHMM format
    int currentTime = TimeHour(TimeCurrent()) * 100 + TimeMinute(TimeCurrent());
    // Check if current time is outside of trading hours or if ATR is above threshold
    if (excludeTime && (excludeStartTime <= currentTime && currentTime <= excludeEndTime)) {
        return;
    }

    if ((Ask - Bid) >= maxAcceptedSpread) {
        return;
    }

    firstBuyEntry = Ask;
    firstSellEntry = Bid;

    OpenOrder(OP_BUY, baseLot, firstBuyEntry, 0, 0, "First Buy Entry");
    OpenOrder(OP_SELL, baseLot, firstSellEntry, 0, 0, "First Sell Entry");
}

void OpenOrder(int orderType, double lotSize, double price, double sl, double tp, string comment)
{
    int ticket = OrderSend(Symbol(), orderType, lotSize, price, 2, sl, tp, comment, 0, 0, clrNONE);
    if (ticket < 0)
    {
        Print("Error opening order: ", GetLastError());
    }
    else
    {
        Print("Order opened successfully. Ticket: ", ticket);
    }
}

int CountOrders(int orderType)
{
    int count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == orderType && OrderSymbol() == Symbol())
        {
            count++;
        }
    }
    return count;
}

void CloseAllOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderSymbol() == Symbol())
        {
            bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 2, clrNONE);
            if (!result)
            {
                Print("Error closing order: ", GetLastError());
            }
        }
    }
}

void ResetAll()
{
    firstBuyEntry = 0;
    firstSellEntry = 0;
}

void OnDeinit(const int reason)
{
    Print("EA de-initialized.");
}
