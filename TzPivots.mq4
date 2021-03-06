//+------------------------------------------------------------------+
//|                                                     TzPivots.mq4 |
//|                                 Copyright © 2008-2022, EarnForex |
//|                                        https://www.earnforex.com |
//|                                   Based on indicator by Shimodax |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2008-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/TzPivots/"
#property version   "1.01"
#property strict

#property indicator_chart_window
#property indicator_plots 0

/* Introduction:

   Calculation of pivot and similar levels based on time zones.
   If you want to modify the colors, please scroll down to line
   200 and below (where it says "Calculate Levels") and change
   the colors.  Valid color names can be obtained by placing
   the cursor on a color name (e.g. somewhere in the word "Orange"
   and pressing F1).

   Time-Zone Inputs:

   LocalTimeZone: TimeZone for which MT4 shows your local time,
                  e.g. 1 or 2 for Europe (GMT+1 or GMT+2 (daylight
                  savings time).  Use zero for no adjustment.

                  The MetaQuotes demo server uses GMT +2.

   DestTimeZone:  TimeZone for the session from which to calculate
                  the levels (e.g. 1 or 2 for the European session
                  (without or with daylight savings time).
                  Use zero for GMT


   Example: If your MT server is living in the EST (Eastern Standard Time,
            GMT-5) zone and want to calculate the levels for the London trading
            session (European time in summer GMT+1), then enter -5 for
            LocalTimeZone, 1 for Dest TimeZone.

            Please understand that the LocalTimeZone setting depends on the
            time on your MetaTrader charts (for example the demo server
            from MetaQuotes always lives in CDT (+2) or CET (+1), no matter
            what the clock on your wall says.

            If in doubt, leave everything to zero.
*/

input int LocalTimeZone = 0;
input int DestTimeZone = 0;
input ENUM_LINE_STYLE LineStyle = STYLE_DOT;
input int LineThickness = 1;

input bool ShowPivots = true;
input color PivotColor = clrMagenta;
input color SupportColor = clrBlue;
input color ResistanceColor = clrRed;

input bool ShowMidPivot = true;
input color MidPivotColor = clrLightGray;
input ENUM_LINE_STYLE LineStyleMidP = STYLE_DOT;
input int LineThicknessMidP = 1;

input color LabelColor = clrGray;

input bool ShowComment = false;
input ENUM_BASE_CORNER CommentaryCorner = CORNER_LEFT_UPPER;

input bool ShowHighLowOpen = false;
input color HighLowOpenColor = clrOrange;

input bool ShowSweetSpots = false;
input color SweetSpotsColor = clrDeepSkyBlue;

input bool ShowFibos = false;
input color FibosColor = clrGoldenrod;

input bool ShowCamarilla = false;
input color CamarillaColor = clrDimGray;

input bool ShowLevelPrices = true;

input color DaySeparator = clrDarkGray;
input color DayLabel = clrDarkGray;

input int BarForLabels = 10;    // Number of bars from right, where line labels will be shown.

input bool DebugLogger = false;

/*
   TradingHoursFrom: First hour of the trading session in the destination
                     time zone.

   TradingHoursTo: Last hour of the trading session in the destination
                   time zone (the hour starting with this value is excluded,
                   i.e. 18 means up to 17:59 o'clock)

   Example: If your server is in the EST (Eastern Standard Time, GMT-5)
            zone and want to calculate the levels for the London trading
            session (European time GMT+1, 08:00 - 17:00), then enter
            -5 for LocalTimeZone, 1 for DestTimeZone, 8 for HoursFrom
            and 17 for HoursTo.
*/

input int TradingHoursFrom = 0;
input int TradingHoursTo = 24;

input int ShiftDays = 0; // ShiftDays: Calculate pivots from N days back.

input string ObjectPrefix = "PIVOT-";

int OnInit()
{
    if (PeriodSeconds() > 1440 * 60)
    {
        Print("Timeframes higher than D1 are not supported.");
        return INIT_FAILED;
    }
    if ((TradingHoursFrom < 0) || (TradingHoursTo > 24) || (TradingHoursTo <= TradingHoursFrom))
    {
        Print("Wrong trading hours settings: ", TradingHoursFrom, " - ", TradingHoursTo, ".");
        return INIT_FAILED;
    }
    if (ShiftDays < 0)
    {
        Print("Sessions shift should be positive!");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), ObjectPrefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    static datetime timelastupdate = 0;

    datetime startofday = 0,
             startofyesterday = 0;

    double today_high = 0,
           today_low = 0,
           today_open = 0,
           yesterday_high = 0,
           yesterday_open = 0,
           yesterday_low = 0,
           yesterday_close = 0;

    int idxfirstbaroftoday = 0,
        idxfirstbarofyesterday = 0,
        idxlastbarofyesterday = 0;

    // Wait for a new bar before updating:
    if (Time[0] <= timelastupdate) return 0;
    timelastupdate = Time[0];

    if (DebugLogger)
    {
        Print("Local time current bar: ", TimeToString(Time[0]));
        Print("Destination time current bar: ", TimeToString(Time[0] - (LocalTimeZone - DestTimeZone) * 3600), ", Timezone difference = ", LocalTimeZone - DestTimeZone);
    }

    // Let's find out which hour bars make today and yesterday.
    ComputeDayIndices(LocalTimeZone, DestTimeZone, idxfirstbaroftoday, idxfirstbarofyesterday, idxlastbarofyesterday);

    startofday = Time[idxfirstbaroftoday]; // Datetime (x-value) for labes on horizontal bars.
    startofyesterday = Time[idxfirstbarofyesterday]; // Datetime (x-value) for labes on horizontal bars.

    yesterday_high = High[iHighest(Symbol(), Period(), MODE_HIGH, idxfirstbarofyesterday - idxlastbarofyesterday + 1, idxlastbarofyesterday)];
    yesterday_low = Low[iLowest(Symbol(), Period(), MODE_LOW, idxfirstbarofyesterday - idxlastbarofyesterday + 1, idxlastbarofyesterday)];
    yesterday_open = Open[idxfirstbarofyesterday];
    yesterday_close = Close[idxlastbarofyesterday];

    today_open = Open[idxfirstbaroftoday];

    today_high = High[iHighest(Symbol(), Period(), MODE_HIGH, idxfirstbaroftoday + 1, 0)];
    today_low = Low[iLowest(Symbol(), Period(), MODE_LOW, idxfirstbaroftoday + 1, 0)];

    // Draw the vertical lines that mark the time span.
    double p = (yesterday_high + yesterday_low + yesterday_close) / 3;
    SetTimeLine("YesterdayStart", "yesterday", idxfirstbarofyesterday, DayLabel, p - 4 * Point());
    if (TradingHoursTo != 24) SetTimeLine("YesterdayEnd", "yesterday end", idxlastbarofyesterday, DayLabel, p - 4 * Point()); // Yesterday end != Today start.
    SetTimeLine("TodayStart", "today", idxfirstbaroftoday, DayLabel, p - 4 * Point());

    if (DebugLogger)
        Print("Timezoned values: yo= ", yesterday_open, ", yc = ", yesterday_close, ", yhigh = ", yesterday_high, ", ylow = ", yesterday_low, ", to = ", today_open);

    // Calculate levels.
    double q, d, r1, r2, r3, s1, s2, s3;

    d = today_high - today_low;
    q = yesterday_high - yesterday_low;
    p = NormalizeDouble(p, _Digits);

    r1 = 2 * p - yesterday_low;
    r1 = NormalizeDouble(r1, _Digits);

    r2 = p + yesterday_high - yesterday_low; // r2 = p - s1 + r1
    r2 = NormalizeDouble(r2, _Digits);

    r3 = 2 * p + yesterday_high - 2 * yesterday_low;
    r3 = NormalizeDouble(r3, _Digits);

    s1 = 2 * p - yesterday_high;
    s1 = NormalizeDouble(s1, _Digits);

    s2 = p - yesterday_high + yesterday_low; // s2 = p - r1 + s1
    s2 = NormalizeDouble(s2, _Digits);

    s3 = 2 * p - 2 * yesterday_high + yesterday_low;
    s3 = NormalizeDouble(s3, _Digits);

    // High/Low, Open
    if (ShowHighLowOpen)
    {
        SetLevel("Y\'s High", yesterday_high, HighLowOpenColor, LineStyle, LineThickness, startofyesterday);
        SetLevel("T\'s Open", today_open,     HighLowOpenColor, LineStyle, LineThickness, startofday);
        SetLevel("Y\'s Low",  yesterday_low,  HighLowOpenColor, LineStyle, LineThickness, startofyesterday);
    }

    // Sweet Spots
    if (ShowSweetSpots)
    {
        int ssp1, ssp2;
        double ds1, ds2;

        ssp1 = (int)(Bid / Point());
        ssp1 = ssp1 - ssp1 % 50;
        ssp2 = ssp1 + 50;

        ds1 = ssp1 * Point();
        ds2 = ssp2 * Point();

        SetLevel(DoubleToString(ds1, _Digits), ds1, SweetSpotsColor, LineStyle, LineThickness, Time[10]);
        SetLevel(DoubleToString(ds2, _Digits), ds2, SweetSpotsColor, LineStyle, LineThickness, Time[10]);
    }

    // Pivot Lines
    if (ShowPivots)
    {
        SetLevel("R1", r1,   ResistanceColor, LineStyle, LineThickness, startofday);
        SetLevel("R2", r2,   ResistanceColor, LineStyle, LineThickness, startofday);
        SetLevel("R3", r3,   ResistanceColor, LineStyle, LineThickness, startofday);
        SetLevel("Pivot", p, PivotColor,      LineStyle, LineThickness, startofday);
        SetLevel("S1", s1,   SupportColor,    LineStyle, LineThickness, startofday);
        SetLevel("S2", s2,   SupportColor,    LineStyle, LineThickness, startofday);
        SetLevel("S3", s3,   SupportColor,    LineStyle, LineThickness, startofday);
    }

    // Fibos of yesterday's range
    if (ShowFibos)
    {
        // .618, .5 and .382
        SetLevel("Low - 61.8%",  yesterday_low -  q * 0.618, FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("Low - 38.2%",  yesterday_low -  q * 0.382, FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("Low + 38.2%",  yesterday_low +  q * 0.382, FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("LowHigh 50%",  yesterday_low +  q * 0.5,   FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("High - 38.2%", yesterday_high - q * 0.382, FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("High + 38.2%", yesterday_high + q * 0.382, FibosColor, LineStyle, LineThickness, startofday);
        SetLevel("High + 61.8%", yesterday_high + q * 0.618, FibosColor, LineStyle, LineThickness, startofday);
    }

    // Camarilla Lines
    if (ShowCamarilla)
    {
        double h4, h3, l4, l3;
        h4 = q * 0.55 + yesterday_close;
        h3 = q * 0.27 + yesterday_close;
        l3 = yesterday_close - q * 0.27;
        l4 = yesterday_close - q * 0.55;
        SetLevel("H3", h3, CamarillaColor, LineStyle, LineThickness, startofday);
        SetLevel("H4", h4, CamarillaColor, LineStyle, LineThickness, startofday);
        SetLevel("L3", l3, CamarillaColor, LineStyle, LineThickness, startofday);
        SetLevel("L4", l4, CamarillaColor, LineStyle, LineThickness, startofday);
    }

    // Midpoints Pivots
    if (ShowMidPivot)
    {
        // Middle levels between pivots
        SetLevel("MR3", (r2 + r3) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
        SetLevel("MR2", (r1 + r2) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
        SetLevel("MR1", (p +  r1) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
        SetLevel("MS1", (p +  s1) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
        SetLevel("MS2", (s1 + s2) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
        SetLevel("MS3", (s2 + s3) / 2, MidPivotColor, LineStyleMidP, LineThicknessMidP, startofday);
    }

    // Comment
    if (ShowComment)
    {
        //string comment = "";
        string comment1 = "Range: Yesterday " + DoubleToString(MathRound(q / Point()), 0)   + " pips, Today " + DoubleToString(MathRound(d / Point()), 0) + " pips";
        string comment2 = "Highs: Yesterday " + DoubleToString(yesterday_high, _Digits)  + ", Today " + DoubleToString(today_high, _Digits);
        string comment3 = "Lows:  Yesterday " + DoubleToString(yesterday_low, _Digits)   + ", Today " + DoubleToString(today_low, _Digits);
        string comment4 = "Close: Yesterday " + DoubleToString(yesterday_close, _Digits);

        int y = 10;
        PlaceCommentLabel(y, comment1);
        y += 15;
        PlaceCommentLabel(y, comment2);
        y += 15;
        PlaceCommentLabel(y, comment3);
        y += 15;
        PlaceCommentLabel(y, comment4);
    }

    return rates_total;
}

//+------------------------------------------------------------------+
//| Computes indices of the first/last bars of yesterday and today.  |
//+------------------------------------------------------------------+
void ComputeDayIndices(int tzlocal, int tzdest, int &idxfirstbaroftoday, int &idxfirstbarofyesterday, int &idxlastbarofyesterday)
{
    int tzdiff = tzlocal - tzdest,
        tzdiffsec = tzdiff * 3600,
        dayminutes = 24 * 60,
        barsperday = dayminutes / Period();

    idxfirstbaroftoday = 0;
    idxfirstbarofyesterday = 0;
    idxlastbarofyesterday = 0;

    int cnt = 0; // Either 0 - for normal cases; or N - for a shifted trading session.

    if (ShiftDays > 0) // Need another starting Time[0] to work with.
    {
        for (int i = 1; i < Bars; i++)
        {
            if (TimeDayOfYear(Time[i] - tzdiffsec) != TimeDayOfYear(Time[i - 1] - tzdiffsec)) cnt++;
            if (cnt == ShiftDays)
            {
                cnt = i;
                break;
            }
        }
    }

    if ((TradingHoursTo < 24) && (TimeHour(Time[cnt] - tzdiffsec) >= TradingHoursTo)) // Trading hours given via input parameters, current hour is after last hour.
    { // Starting hour of today will be today, right after the end of the selected trading hours.
        for (int i = cnt + 1; i <= cnt + barsperday; i++)
        {
            if (TimeHour(Time[i] - tzdiffsec) < TradingHoursTo) // Found.
            {
                idxfirstbaroftoday = i - 1;
                break;
            }
            if (TimeHour(Time[i] - tzdiffsec) < TradingHoursFrom) break; // Couldn't find?
        }
    }
    else // Otherwise, will be found using the normal method.
    {
        int daytoday = TimeDayOfYear(Time[cnt] - tzdiffsec); // What day is today in the dest timezone?
    
        // Search  backwards for the last occrrence (backwards) of the day today (today's first bar)
        for (int i = cnt + 1; i <= cnt + barsperday + 1; i++)
        {
            if (TimeDayOfYear(Time[i] - tzdiffsec) != daytoday)
            {
                idxfirstbaroftoday = i - 1;
                break;
            }
        }
    }
    
    if (TradingHoursTo == 24) idxlastbarofyesterday = idxfirstbaroftoday + 1; // Simple case.
    else
    {
        // Go back to find the last bar of latest finished selected trading session.
        for (int i = idxfirstbaroftoday + 1; i <= idxfirstbaroftoday + barsperday; i++)
        {
            if (TimeHour(Time[i] - tzdiffsec) < TradingHoursTo) // Found.
            {
                idxlastbarofyesterday = i;
                break;
            }
            if (TimeHour(Time[i] - tzdiffsec) < TradingHoursFrom) break; // Couldn't find?
        }
    }
    
    
    if (TradingHoursFrom > 0)
    {
        // Find first bar with hour < TradingHoursFrom, then step forward.
        for (int j = idxlastbarofyesterday; j <= idxlastbarofyesterday + barsperday; j++)
        {
            if (TimeHour(Time[j] - tzdiffsec) < TradingHoursFrom)
            {
                idxfirstbarofyesterday = j - 1;
                break;
            }
        }
    }
    else // Normal method.
    {
        int lastbarofyesterday_day = TimeDayOfYear(Time[idxlastbarofyesterday]);
    
        for (int j = idxlastbarofyesterday; j <= idxlastbarofyesterday + barsperday; j++)
        {
            if (TimeDayOfYear(Time[j] - tzdiffsec) != lastbarofyesterday_day)
            {
                idxfirstbarofyesterday = j - 1;
                break;
            }
        }
    }

    if (DebugLogger)
    {
        Print("Dest time zone\'s current day starts:", TimeToString(Time[idxfirstbaroftoday]),
              " (local time), idxbar= ", idxfirstbaroftoday);
        Print("Dest time zone\'s previous day starts:", TimeToString(Time[idxfirstbarofyesterday]),
              " (local time), idxbar= ", idxfirstbarofyesterday);
        Print("Dest time zone\'s previous day ends:", TimeToString(Time[idxlastbarofyesterday]),
              " (local time), idxbar= ", idxlastbarofyesterday);
    }
}

//+------------------------------------------------------------------+
//| Creates a line and a label with optional level price.            |
//+------------------------------------------------------------------+
void SetLevel(string text, double level, color col, int linestyle, int thickness, datetime startofday)
{
    string labelname = "PIVOT-" + text + "Label",
           linename = "PIVOT-" + text + "Line",
           pricelabel;

    // Create or move the horizontal line.
    if (ObjectFind(ChartID(), linename) < 0)
    {
        ObjectCreate(ChartID(), linename, OBJ_TREND, 0, startofday, level, Time[0], level);
        ObjectSetInteger(ChartID(), linename, OBJPROP_STYLE, linestyle);
        ObjectSetInteger(ChartID(), linename, OBJPROP_COLOR, col);
        ObjectSetInteger(ChartID(), linename, OBJPROP_WIDTH, thickness);
    }
    else
    {
        ObjectMove(ChartID(), linename, 1, Time[0], level);
        ObjectMove(ChartID(), linename, 0, startofday, level);
    }

    // Put a label on the line.
    if (ObjectFind(ChartID(), labelname) < 0)
    {
        ObjectCreate(ChartID(), labelname, OBJ_TEXT, 0, MathMin(Time[BarForLabels], startofday + 2 * Period() * 60), level);
    }
    else
    {
        ObjectMove(ChartID(), labelname, 0, MathMin(Time[BarForLabels], startofday + 2 * Period() * 60), level);
    }

    pricelabel = text;
    if ((ShowLevelPrices) && (StringToInteger(text) == 0))
        pricelabel += ": " + DoubleToString(level, _Digits);

    ObjectSetString(ChartID(), labelname, OBJPROP_TEXT, pricelabel);
    ObjectSetInteger(ChartID(), labelname, OBJPROP_FONTSIZE, 8);
    ObjectSetString(ChartID(), labelname, OBJPROP_FONT, "Arial");
    ObjectSetInteger(ChartID(), labelname, OBJPROP_COLOR, LabelColor);
}

//+------------------------------------------------------------------+
//| Creates a vertical line with a text label.                       |
//+------------------------------------------------------------------+
void SetTimeLine(string objname, const string text, const int idx, const color col, const double vleveltext)
{
    objname = "PIVOT-" + objname;
    datetime x = Time[idx];

    if (ObjectFind(ChartID(), objname) < 0)
        ObjectCreate(ChartID(), objname, OBJ_VLINE, 0, x, 0);
    else
    {
        ObjectMove(ChartID(), objname, 0, x, 0);
    }

    ObjectSetInteger(ChartID(), objname, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(ChartID(), objname, OBJPROP_COLOR, DaySeparator);

    if (ObjectFind(ChartID(), objname + "Label") < 0)
        ObjectCreate(ChartID(), objname + "Label", OBJ_TEXT, 0, x, vleveltext);
    else
        ObjectMove(ChartID(), objname + "Label", 0, x, vleveltext);

    ObjectSetString(ChartID(), objname + "Label", OBJPROP_TEXT, text);
    ObjectSetInteger(ChartID(), objname + "Label", OBJPROP_FONTSIZE, 8);
    ObjectSetString(ChartID(), objname + "Label", OBJPROP_FONT, "Arial");
    ObjectSetInteger(ChartID(), objname + "Label", OBJPROP_COLOR, col);
}

//+------------------------------------------------------------------+
//| Places a line of commentary at a given y shift and in a given    |
//| corner.                                                          |
//+------------------------------------------------------------------+
void PlaceCommentLabel(int y, const string comment)
{
    if ((CommentaryCorner == CORNER_LEFT_LOWER) || (CommentaryCorner == CORNER_RIGHT_LOWER)) y += 10;
    ObjectCreate(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_YDISTANCE, y);
    ObjectSetInteger(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_CORNER, CommentaryCorner);
    ENUM_ANCHOR_POINT anchor = ANCHOR_RIGHT_UPPER;
    if ((CommentaryCorner == CORNER_LEFT_UPPER) || (CommentaryCorner == CORNER_LEFT_LOWER)) anchor = ANCHOR_LEFT_UPPER;
    ObjectSetInteger(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_ANCHOR, anchor);
    ObjectSetString(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_TEXT, comment);
    ObjectSetInteger(ChartID(), "PIVOT-Comment" + IntegerToString(y), OBJPROP_COLOR, LabelColor);
}
//+------------------------------------------------------------------+