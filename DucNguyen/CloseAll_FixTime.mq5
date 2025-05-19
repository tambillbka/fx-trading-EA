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

    for (int i = total - 1; i >= 0; i--)
    {
        if (!PositionSelectByIndex(i))
            continue;

        if (PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double volume = PositionGetDouble(POSITION_VOLUME);

        Print("Attempting to close position: ", ticket, ", Volume: ", volume);

        if (trade.PositionClose(ticket))
        {
            Print("Closed position: ", ticket);
            success = true;
        }
        else
        {
            Print("Failed to close position: ", ticket, ". Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
        }
    }

    return success;
}
