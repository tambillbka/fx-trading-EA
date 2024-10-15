input double targetTP = 3.0;

// GMT+7 time input
input int Hour = 19;
input int Min = 29;
input int Second = 58;

// Server time
int serverHour;
int serverMin;
int serverSec;

int OnInit()
{
    // Clear old timer
    EventKillTimer();

    // Convert GMT+7 from input to Server time
    datetime gmt7Time = StrToTime(StringFormat("%02d:%02d:%02d", Hour, Min, Second)) - 7 * 3600;
    MqlDateTime serverTime;
    TimeToStruct(gmt7Time, serverTime);

    serverHour = serverTime.hour;
    serverMin = serverTime.min;
    serverSec = serverTime.sec;

    Print("Execute time: " + IntegerToString(serverHour) + ":" + IntegerToString(serverMin) + ":" + IntegerToString(serverSec));
    Print("EA initialized successfully.");

    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

void OnTimer()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime currentStruct;
    TimeToStruct(currentTime, currentStruct);

    int currentHour = currentStruct.hour;
    int currentMin = currentStruct.min;
    int currentSec = currentStruct.sec;

    // Check if current time matches the specified time
    if (currentHour == serverHour && currentMin == serverMin && currentSec >= serverSec)
    {
        if (CloseOrders(OP_BUY) || (OrdersTotal() == 1 && SelectFirstOrderTP(OP_SELL) == 0)) {
            // Modify the remaining Sell order TP
            ModifyOrders(OP_SELL, Bid - targetTP);
        } else {
            Print("Cannot close BUY order!!!");
            return;
        }
    }
}

double SelectFirstOrderTP(int orderType) {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderType() == orderType) {
            return OrderTakeProfit();
        }
    }
    return -1;
}

bool CloseOrders(int orderType)
{
    int countBuy = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == orderType && OrderSymbol() == Symbol())
        {
            if (!OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 2, clrNONE))
            {
                Print("Error closing order: ", GetLastError());
                return false;
            }
            countBuy++;
        }
    }
    return countBuy > 0;
}

void ModifyOrders(int orderType, double newTP)
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS) && OrderType() == orderType && OrderSymbol() == Symbol())
        {
            if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), newTP, OrderExpiration(), clrNONE))
            {
                Print("Error modifying order: ", GetLastError());
            }
            else
            {
                Print("Order modified successfully. Ticket: ", OrderTicket());
            }
        }
    }
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("EA de-initialized.");
}