#include <Trade/Trade.mqh>

input int Hour   = 19;  // GMT+7 target hour
input int Min    = 29;  // GMT+7 target minute
input int Second = 58;  // GMT+7 target second

// Server time
int serverHour;
int serverMin;
int serverSec;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // Clear old timer
    EventKillTimer();

    // Convert GMT+7 input time to server time
    datetime gmt7Time = StrToTime(StringFormat("%02d:%02d:%02d", Hour, Min, Second)) - 7 * 3600;
    MqlDateTime serverTimeStruct;
    TimeToStruct(gmt7Time, serverTimeStruct);

    serverHour = serverTimeStruct.hour;
    serverMin  = serverTimeStruct.min;
    serverSec  = serverTimeStruct.sec;

    Print("Execute time (Server): ", serverHour, ":", serverMin, ":", serverSec);

    EventSetTimer(1);  // Check every second
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("EA de-initialized.");
}

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime now = TimeCurrent();
    MqlDateTime nowStruct;
    TimeToStruct(now, nowStruct);

    int currentHour = nowStruct.hour;
    int currentMin  = nowStruct.min;
    int currentSec  = nowStruct.sec;

    if (currentHour == serverHour && currentMin >= serverMin && currentSec >= serverSec)
    {
        if (CloseAllOrders())
        {
            Print("Closed all open positions.");
            EventKillTimer();
            return;
        }
        else
        {
            Print("No positions were closed or failed to close.");
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions for current symbol                           |
//+------------------------------------------------------------------+
bool CloseAllOrders()
{
    bool anyClosed = false;

    int totalPositions = PositionsTotal();

    for (int i = totalPositions - 1; i >= 0; i--)
    {
        if (!PositionGetTicket(i))
            continue;

        ulong ticket = PositionGetTicket(i);

        if (!PositionSelectByTicket(ticket))
            continue;

        string symbol = PositionGetString(POSITION_SYMBOL);

        if (symbol != _Symbol)
            continue;

        if (trade.PositionClose(symbol))
        {
            Print("Closed position: ", ticket);
            anyClosed = true;
        }
        else
        {
            Print("Failed to close position: ", ticket, " Error: ", trade.ResultRetcode());
        }
    }

    return anyClosed;
}
