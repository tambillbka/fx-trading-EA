#include <Trade/Trade.mqh>

input int Hour = 19;     // GMT+7 Hour
input int Min = 29;      // GMT+7 Minute
input int Second = 58;   // GMT+7 Second

int serverHour;
int serverMin;
int serverSec;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    EventKillTimer();  // Clear old timer first

    // Convert GMT+7 input time to server time
    datetime gmt7Time = StringToTime(StringFormat("%02d:%02d:%02d", Hour, Min, Second)) - 7 * 3600;
    MqlDateTime serverStruct;
    TimeToStruct(gmt7Time, serverStruct);

    serverHour = serverStruct.hour;
    serverMin = serverStruct.min;
    serverSec = serverStruct.sec;

    Print("Target Execution Time (Server): ", serverHour, ":", serverMin, ":", serverSec);

    EventSetTimer(1);  // Run OnTimer() every second
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("EA de-initialized.");
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime now = TimeCurrent();
    MqlDateTime nowStruct;
    TimeToStruct(now, nowStruct);

    int currentHour = nowStruct.hour;
    int currentMin = nowStruct.min;
    int currentSec = nowStruct.sec;

    Print("Timer tick at ", TimeToString(now, TIME_SECONDS));

    if (currentHour == serverHour && currentMin >= serverMin && currentSec >= serverSec)
    {
        if (CloseAllOrders())
        {
            Print("All positions closed at ", TimeToString(now, TIME_SECONDS));
            EventKillTimer();
        }
        else
        {
            Print("No positions closed or failed to close.");
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions on the current symbol                        |
//+------------------------------------------------------------------+
bool CloseAllOrders()
{
    bool success = false;
    string symbol = Symbol();
    int total = PositionsTotal();

    int totalOrders = PositionsTotal();

    if (totalOrders > 0) {
        for (int i = totalOrders - 1; i >= 0; i--) {
            ulong positionTicket = PositionGetTicket(i);

            if (PositionSelectByTicket(positionTicket)) {
                if (trade.PositionClose(positionTicket)) {
                    Print("Position closed successfully: Ticket ", positionTicket);
                    success = true;
                } else {
                    Print("Failed to close position: Ticket ", positionTicket, " Error: ", GetLastError());
                    return false;
                }
            }
        }
    }
    return success;
}
