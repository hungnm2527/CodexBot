#pragma once

bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &last_bar_time)
  {
   datetime current = iTime(_Symbol, tf, 0);
   if(current <= 0)
      return false;
   if(last_bar_time == 0)
     {
      last_bar_time = current;
      return false;
     }
   if(current != last_bar_time)
     {
      last_bar_time = current;
      return true;
     }
   return false;
  }

int ParseTimeToMinutes(const string time_str)
  {
   if(time_str == "")
      return -1;
   string parts[];
   int count = StringSplit(time_str, ':', parts);
   if(count < 2)
      return -1;
   int hour = (int)StringToInteger(parts[0]);
   int minute = (int)StringToInteger(parts[1]);
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

bool IsWithinTimeWindow(const datetime t, const string start_str, const string end_str)
  {
   int start_min = ParseTimeToMinutes(start_str);
   int end_min = ParseTimeToMinutes(end_str);
   if(start_min < 0 || end_min < 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int now_min = dt.hour * 60 + dt.min;
   if(start_min <= end_min)
      return (now_min >= start_min && now_min <= end_min);
   return (now_min >= start_min || now_min <= end_min);
  }

bool IsWithinSession(const datetime t, const bool use_filter, const int start_hour, const int end_hour)
  {
   if(!use_filter)
      return true;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int hour = dt.hour;
   if(start_hour <= end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool IsManualBlocked(const datetime t, const string block1_start, const string block1_end, const string block2_start, const string block2_end)
  {
   if(IsWithinTimeWindow(t, block1_start, block1_end))
      return true;
   if(IsWithinTimeWindow(t, block2_start, block2_end))
      return true;
   return false;
  }

string TimeToStringShort(const datetime t)
  {
   return TimeToString(t, TIME_DATE|TIME_MINUTES);
  }

