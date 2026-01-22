#ifndef XAGUSD_STACK_UI_MQH
#define XAGUSD_STACK_UI_MQH

string UI_PREFIX = "XAGUSD_STACK_";

void CreateLabel(const long chart_id, const string name, const int x, const int y, const string text, const color col, const int fontsize)
  {
   if(ObjectFind(chart_id, name) < 0)
     {
      ObjectCreate(chart_id, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
      ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, fontsize);
      ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
     }
   else
     {
      ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
      ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, fontsize);
     }
  }

void CreatePanelBackground(const long chart_id, const string name, const int width, const int height, const color bg)
  {
   if(ObjectFind(chart_id, name) < 0)
     {
      ObjectCreate(chart_id, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, 5);
      ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, 5);
      ObjectSetInteger(chart_id, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(chart_id, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, bg);
      ObjectSetInteger(chart_id, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
      ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
     }
  }

void DeleteUIPanel(const long chart_id)
  {
   int total = ObjectsTotal(chart_id, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chart_id, i);
      if(StringFind(name, UI_PREFIX) == 0)
         ObjectDelete(chart_id, name);
     }
  }

void UpdateUIPanel(const long chart_id, const color text_color, const int font_size,
                   const string header, const string line1, const string line2, const string line3,
                   const string line4, const string line5, const string line6, const string line7)
  {
   CreatePanelBackground(chart_id, UI_PREFIX + "BG", 320, 160, InpPanelBgColor);

   int x = 12;
   int y = 12;
   int step = 16;

   CreateLabel(chart_id, UI_PREFIX + "H", x, y, header, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L1", x, y + step, line1, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L2", x, y + step * 2, line2, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L3", x, y + step * 3, line3, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L4", x, y + step * 4, line4, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L5", x, y + step * 5, line5, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L6", x, y + step * 6, line6, text_color, font_size);
   CreateLabel(chart_id, UI_PREFIX + "L7", x, y + step * 7, line7, text_color, font_size);
  }

void DrawSignalArrow(const long chart_id, const string name, const datetime t, const double price, const color col, const bool is_buy)
  {
   if(ObjectFind(chart_id, name) >= 0)
      return;
   ObjectCreate(chart_id, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
   ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, is_buy ? 233 : 234);
  }

void DrawHLine(const long chart_id, const string name, const double price, const color col, const string text)
  {
   if(ObjectFind(chart_id, name) < 0)
     {
      ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price);
     }
   ObjectSetDouble(chart_id, name, OBJPROP_PRICE, price);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
  }

#endif // XAGUSD_STACK_UI_MQH
