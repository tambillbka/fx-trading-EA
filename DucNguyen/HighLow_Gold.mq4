//+------------------------------------------------------------------+
//|                                                     CustomEA.mq4|
//|                                    Based on user-defined design |
//+------------------------------------------------------------------+
#property strict

//--- input parameters
input double baseLot = 0.01;
input double takeProfit = 3.0;
input double stopLoss = 2.0;
input int multiplier = 2;
input double previousCandleDiff = 1.0;

//--- custom structure for High/Low TP
double highTP = 0.0;
double lowTP = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   double ask = NormalizeDouble(Ask, Digits);
   double bid = NormalizeDouble(Bid, Digits);

   // Check current price is over HighLowTP or not
   if (highTP != 0 && lowTP != 0) {
      if (ask <= lowTP || bid >= highTP) {
         clearAllSeriesStatus();
      }
   }

   int totalBuy = countOrders(OP_BUY);
   int totalSell = countOrders(OP_SELL);
   int totalBuySell = totalBuy + totalSell;

   if (totalBuySell == 1) {
      for (int i = OrdersTotal() - 1; i >= 0; i--) {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_BUY) {
               if (countOrders(OP_SELLSTOP) > 0) return;

               double price = NormalizeDouble(OrderStopLoss(), Digits);
               double lot = OrderLots() * multiplier;
               double tp = NormalizeDouble(lowTP, Digits);
               double sl = NormalizeDouble(price + stopLoss, Digits);
               sendOrder(OP_SELLSTOP, lot, price, sl, tp);
               return;

            } else if (OrderType() == OP_SELL) {
               if (countOrders(OP_BUYSTOP) > 0) return;

               double price = NormalizeDouble(OrderStopLoss(), Digits);
               double lot = OrderLots() * multiplier;
               double tp = NormalizeDouble(highTP, Digits);
               double sl = NormalizeDouble(price - stopLoss, Digits);
               sendOrder(OP_BUYSTOP, lot, price, sl, tp);
               return;
            }
         }
      }
   } else if (totalBuySell == 0 && !isInSeries()) {
      findingFirstOrder();
   }
}

//+------------------------------------------------------------------+
//| Open initial market order based on previous candle               |
//+------------------------------------------------------------------+
void findingFirstOrder() {
   int orderType = getOrderType();
   double ask = NormalizeDouble(Ask, Digits);
   double bid = NormalizeDouble(Bid, Digits);

   if (orderType == OP_BUY) {
      double tp = NormalizeDouble(ask + takeProfit, Digits);
      double sl = NormalizeDouble(ask - stopLoss, Digits);
      sendOrder(OP_BUY, baseLot, ask, sl, tp);

      highTP = tp;
      lowTP = sl - takeProfit;

   } else if (orderType == OP_SELL) {
      double tp = NormalizeDouble(bid - takeProfit, Digits);
      double sl = NormalizeDouble(bid + stopLoss, Digits);
      sendOrder(OP_SELL, baseLot, bid, sl, tp);

      lowTP = tp;
      highTP = sl + takeProfit;
   }
}

//+------------------------------------------------------------------+
//| Determine trade direction based on previous candle               |
//+------------------------------------------------------------------+
int getOrderType() {
   double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
   double close = iClose(Symbol(), PERIOD_CURRENT, 1);
   if (MathAbs(open - close) >= previousCandleDiff * Point) {
      if (close > open) return OP_BUY;
      if (open > close) return OP_SELL;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Clear all active trades and pending orders                       |
//+------------------------------------------------------------------+
void clearAllSeriesStatus() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol() == Symbol()) {
            if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 3, clrRed)) {
               OrderDelete(OrderTicket());
            }
         }
      }
   }
   highTP = 0.0;
   lowTP = 0.0;
}

//+------------------------------------------------------------------+
//| Count open orders of a specific type                             |
//+------------------------------------------------------------------+
int countOrders(int type) {
   int count = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderType() == type && OrderSymbol() == Symbol()) count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if in a series                                             |
//+------------------------------------------------------------------+
bool isInSeries() {
   return (highTP != 0.0 || lowTP != 0.0);
}

//+------------------------------------------------------------------+
//| Send any order: market or pending                               |
//+------------------------------------------------------------------+
bool sendOrder(int type, double lot, double price, double sl, double tp) {
   int ticket = OrderSend(Symbol(), type, lot, price, 3, sl, tp, "EA Order", 0, 0, clrBlue);
   if (ticket < 0) {
      Print("OrderSend failed: ", GetLastError());
      return false;
   }
   return true;
}
