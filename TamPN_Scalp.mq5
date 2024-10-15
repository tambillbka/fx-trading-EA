#include <Trade\Trade.mqh>

// Create a trade object for placing orders
CTrade trade;

// Input parameters
input double distance = 0.3;  // Distance in pips
input double lotSize = 0.01;   // Lot size

// Button definitions
#define BTN_SELL_BUY "Upper Trade"
#define BTN_BUY_SELL "Lower Trade"

// Button dimensions
#define BUTTON_WIDTH 200
#define BUTTON_HEIGHT 50

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
{
    // Set chart type to Candlestick
    ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
    ChartSetInteger(0, CHART_SCALE, 3);

    // Set chart colors based on your template configuration
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, 3943424);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, 16777215);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, 16776960);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, 11823615);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, 16776960);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, 11823615);
    ChartSetInteger(0, CHART_COLOR_CHART_LINE, 16776960);
    ChartSetInteger(0, CHART_COLOR_VOLUME, 10526303);
    ChartSetInteger(0, CHART_COLOR_ASK, 255);
    ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, 255);

    // Redraw the chart to apply changes
    ChartRedraw();

    // Additional EA initialization logic
    CreateButton(BTN_SELL_BUY, 10, 50, "Upper Trade", clrBlue);
    CreateButton(BTN_BUY_SELL, 250, 50, "Lower Trade", clrRed);
}

//+------------------------------------------------------------------+
//| Button creation function                                         |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, string text, uint back_clr)
{
    if (!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
    {
        Print("Failed to create button: ", name);
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);

    // Set button size
    ObjectSetInteger(0, name, OBJPROP_XSIZE, BUTTON_WIDTH);   // Set button width
    ObjectSetInteger(0, name, OBJPROP_YSIZE, BUTTON_HEIGHT);  // Set button height
    
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, back_clr);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectDelete(0, BTN_SELL_BUY);  // Corrected to include chart ID
    ObjectDelete(0, BTN_BUY_SELL);   // Corrected to include chart ID
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (ObjectGetInteger(0, BTN_SELL_BUY, OBJPROP_STATE) == 1)
    {
        AddSellBuy();
        ObjectSetInteger(0, BTN_SELL_BUY, OBJPROP_STATE, 0); // Reset button state
    }
    if (ObjectGetInteger(0, BTN_BUY_SELL, OBJPROP_STATE) == 1)
    {
        AddBuySell();
        ObjectSetInteger(0, BTN_BUY_SELL, OBJPROP_STATE, 0); // Reset button state
    }
}

//+------------------------------------------------------------------+
//| Add Sell Limit and Buy Stop logic                                |
//+------------------------------------------------------------------+
void AddSellBuy()
{
    double askPrice;
    SymbolInfoDouble(Symbol(), SYMBOL_ASK, askPrice);

    double buyStopPrice = askPrice + distance;  // Adjust for point value

    // Place Buy Stop order
    if (trade.BuyStop(lotSize, buyStopPrice, Symbol()))
    {
        // Buy Stop placed successfully, now place Sell Limit
        double sellLimitPrice = buyStopPrice + 0.2;  // Adjust for point value
        if (trade.SellLimit(lotSize, sellLimitPrice, Symbol()))
            Print("Sell Limit placed successfully");
        else
            Print("Failed to place Sell Limit: ", trade.ResultRetcode());
    }
    else
    {
        Print("Failed to place Buy Stop: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Add Buy Limit and Sell Stop logic                                |
//+------------------------------------------------------------------+
void AddBuySell()
{
    double bidPrice;
    SymbolInfoDouble(Symbol(), SYMBOL_BID, bidPrice);

    double buyLimitPrice = bidPrice - distance;  // Adjust for point value

    // Place Buy Limit order
    if (trade.BuyLimit(lotSize, buyLimitPrice, Symbol()))
    {
        // Buy Limit placed successfully, now place Sell Stop
        double sellStopPrice = buyLimitPrice - 0.2;  // Adjust for point value
        if (trade.SellStop(lotSize, sellStopPrice, Symbol()))
            Print("Sell Stop placed successfully");
        else
            Print("Failed to place Sell Stop: ", trade.ResultRetcode());
    }
    else
    {
        Print("Failed to place Buy Limit: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
