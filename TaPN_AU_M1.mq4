// Input parameters
input double baseLot = 0.01;
input double targetProfit = 1.0;
input int startTime = 000;     // Start time for trading in HHMM format
input int endTime = 2300;      // End time for trading in HHMM format
input double ATRThreshold = 2.0; // ATR threshold for trading

// Processing variables
double firstBuyEntry = 0.0;
double firstSellEntry = 0.0;

// EA Common value
int fibonancies[] = {1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144};

// Distances and lots
double DCA_Distances[11] = {0.0, 0.5, 1.0, 1.6, 2.2, 2.8, 3.5, 4.2, 5.0, 6.0, 9.0};
double DCA_Lots[11];

int OnInit()
{
    // Initialize lot sizes based on Fibonacci sequence
    for (int i = 0; i < ArraySize(fibonancies); i++) {
        DCA_Lots[i] = fibonancies[i] * baseLot;
    }

    Print("EA initialized successfully.");
    return(INIT_SUCCEEDED);
}

void OnTick()
{
    // Get current time in HHMM format
    int currentTime = TimeHour(TimeCurrent()) * 100 + TimeMinute(TimeCurrent());

    // Calculate ATR (14-period by default)
    double currentATR = iATR(Symbol(), PERIOD_M1, 14, 0);

    // Check if current time is outside of trading hours or if ATR is above threshold
    if (currentTime < startTime || currentTime > endTime || currentATR > ATRThreshold) {
        return;
    }

    int totalOrders = OrdersTotal();
    if (totalOrders == 0) {
        OpenBuySellPair();
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

void OpenBuySellPair()
{
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
