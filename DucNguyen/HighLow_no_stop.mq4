//+------------------------------------------------------------------+
//|                                                    HedgeEA.mq4   |
//|                        Complete EA Based on Your Design          |
//+------------------------------------------------------------------+
#property strict

extern double baseLot = 0.01;
extern double takeProfit = 3.0;
extern double stopLoss = 2.0;
extern int multiplier = 2;
extern double previousCandleDiff = 1.0;
extern bool manualTrade = false;

struct OpeningTrade {
    int type;
    double entryTp;
    double entrySl;
    double lotSizes;
};

OpeningTrade openingTrade;
bool hasOpeningTrade = false;

int OnInit() {
    hasOpeningTrade = false;
    return INIT_SUCCEEDED;
}

void OnTick() {
    if (!hasOpeningTrade) {
        if (manualTrade) {
            manualCheckFirstEntry();
        } else {
            autoFindFirstEntry();
        }
    } else {
        processSeries();
    }
}

void processSeries() {
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);

    if (openingTrade.type == OP_BUY) {
        if (bid >= openingTrade.entryTp) {
            clearAllSeriesStatus();
        } else if (bid <= openingTrade.entrySl) {
            addNewHedgeOrder();
        }
    } else {
        if (ask <= openingTrade.entryTp) {
            clearAllSeriesStatus();
        } else if (ask >= openingTrade.entrySl) {
            addNewHedgeOrder();
        }
    }
}

void addNewHedgeOrder() {
    double bid = MarketInfo(Symbol(), MODE_BID);
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double lots = openingTrade.lotSizes * multiplier;
    int ticket;

    if (openingTrade.type == OP_BUY) {
        double tp = bid - takeProfit;
        double sl = bid + stopLoss;
        ticket = OrderSend(Symbol(), OP_SELL, lots, bid, 3, sl, tp, "Hedge SELL", 0, 0, Red);
        if (ticket > 0) {
            openingTrade.type = OP_SELL;
            openingTrade.entryTp = tp;
            openingTrade.entrySl = sl;
            openingTrade.lotSizes = lots;
        }
    } else {
        double tp = ask + takeProfit;
        double sl = ask - stopLoss;
        ticket = OrderSend(Symbol(), OP_BUY, lots, ask, 3, sl, tp, "Hedge BUY", 0, 0, Blue);
        if (ticket > 0) {
            openingTrade.type = OP_BUY;
            openingTrade.entryTp = tp;
            openingTrade.entrySl = sl;
            openingTrade.lotSizes = lots;
        }
    }
}

void autoFindFirstEntry() {
    int orderType = getOrderType();
    if (orderType == -1) return;

    double ask = MarketInfo(Symbol(), MODE_ASK);
    double bid = MarketInfo(Symbol(), MODE_BID);
    int ticket;

    if (orderType == OP_BUY) {
        double tp = ask + takeProfit;
        double sl = ask - stopLoss;
        ticket = OrderSend(Symbol(), OP_BUY, baseLot, ask, 3, sl, tp, "Auto BUY", 0, 0, Blue);
        if (ticket > 0) {
            openingTrade.type = OP_BUY;
            openingTrade.entryTp = tp;
            openingTrade.entrySl = sl;
            openingTrade.lotSizes = baseLot;
            hasOpeningTrade = true;
        }
    } else {
        double tp = bid - takeProfit;
        double sl = bid + stopLoss;
        ticket = OrderSend(Symbol(), OP_SELL, baseLot, bid, 3, sl, tp, "Auto SELL", 0, 0, Red);
        if (ticket > 0) {
            openingTrade.type = OP_SELL;
            openingTrade.entryTp = tp;
            openingTrade.entrySl = sl;
            openingTrade.lotSizes = baseLot;
            hasOpeningTrade = true;
        }
    }
}

void manualCheckFirstEntry() {
    int totalBuy = 0, totalSell = 0, ticket;
    double entryLot, entryPrice, tp, sl;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() != Symbol()) continue;
            if (OrderType() == OP_BUY) totalBuy++;
            if (OrderType() == OP_SELL) totalSell++;
        }
    }

    if (totalBuy + totalSell != 1) return;

    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderSymbol() != Symbol()) continue;

            entryLot = OrderLots();
            entryPrice = OrderOpenPrice();

            if (OrderType() == OP_BUY) {
                tp = entryPrice + takeProfit;
                sl = entryPrice - stopLoss;
                OrderModify(OrderTicket(), entryPrice, sl, tp, 0, Blue);
                openingTrade.type = OP_BUY;
                openingTrade.entryTp = tp;
                openingTrade.entrySl = sl;
                openingTrade.lotSizes = entryLot;
                hasOpeningTrade = true;
                break;
            }
            if (OrderType() == OP_SELL) {
                tp = entryPrice - takeProfit;
                sl = entryPrice + stopLoss;
                OrderModify(OrderTicket(), entryPrice, sl, tp, 0, Red);
                openingTrade.type = OP_SELL;
                openingTrade.entryTp = tp;
                openingTrade.entrySl = sl;
                openingTrade.lotSizes = entryLot;
                hasOpeningTrade = true;
                break;
            }
        }
    }
}

int getOrderType() {
    double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
    double close = iClose(Symbol(), PERIOD_CURRENT, 1);
    if (MathAbs(open - close) >= previousCandleDiff) {
        if (close > open) return OP_BUY;
        if (open > close) return OP_SELL;
    }
    return -1;
}

void clearAllSeriesStatus() {
    hasOpeningTrade = false;
}
