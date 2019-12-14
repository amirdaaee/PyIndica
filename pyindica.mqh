//+------------------------------------------------------------------+
//|                                                     pyindica.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
#property tester_library "libzmq.dll"
#property tester_library "libsodium.dll"
#include <Zmq/Zmq.mqh>
#include <JAson.mqh>

input string SocketHost="127.0.0.1";
input int SocketPort=5556;
input string SocketProtocol="tcp";
input int SocketPullTimeout=500;
input bool SocketVerbose=False;

const string Socket_Name="ZMQ_client";
//+------------------------------------------------------------------+
//| Global
//+------------------------------------------------------------------+
Context context(Socket_Name);
Socket socket(context,ZMQ_REQ);
//+------------------------------------------------------------------+
//| Main
//+------------------------------------------------------------------+
void CallServer(int m_Bars,CJAVal &resp_json)
  {
   CJAVal req_json;
   GetLastBars(req_json, m_Bars);
   SendRequest(req_json);
   GetResponse(resp_json);
  }
//+------------------------------------------------------------------+
void SocketInit()
  {
//--- socket connection
   socket.setLinger(0);
   socket.connect(StringFormat("%s://%s:%d",SocketProtocol,SocketHost,SocketPort));
   context.setBlocky(false);
  }
//+------------------------------------------------------------------+
void SocketDeInit()
  {
   context.shutdown();
  }
//+------------------------------------------------------------------+
//| Requesting
//+------------------------------------------------------------------+
void GetLastBars(CJAVal &js_ret, int m_Bars)
  {
   MqlRates rates_array[];
   int rates_count=CopyRates(Symbol(),Period(),1,m_Bars,rates_array);
   if(rates_count>0)
     {
      for(int i=0; i<rates_count; i++)
        {
         js_ret[i]["DateTime"]=TimeToString(rates_array[i].time);
         js_ret[i]["Open"]=DoubleToString(rates_array[i].open);
         js_ret[i]["High"]=DoubleToString(rates_array[i].high);
         js_ret[i]["Low"]=DoubleToString(rates_array[i].low);
         js_ret[i]["Close"]=DoubleToString(rates_array[i].close);
         js_ret[i]["Volume_tick"]=DoubleToString(rates_array[i].tick_volume);
         js_ret[i]["Volume_real"]=DoubleToString(rates_array[i].real_volume);
         js_ret[i]["Spread"]=IntegerToString(rates_array[i].spread);
        }
     }
   else
     {
      js_ret["args"]["data"]="null";
     }
  }
//+------------------------------------------------------------------+
void SendRequest(CJAVal &req_json)
  {
   string req_context="";
   req_json.Serialize(req_context);
   ZmqMsg request(req_context);
   socket.send(request);
   if(SocketVerbose)
     {
      Print("request sent");
     }
  }
//+------------------------------------------------------------------+
//| Response handle
//+------------------------------------------------------------------+
void GetResponse(CJAVal &resp_json)
  {
   ZmqMsg message;
   PollItem items[1];
   socket.fillPollItem(items[0],ZMQ_POLLIN);
   Socket::poll(items,SocketPullTimeout);
//--- empty response handler
   if(items[0].hasInput())
     {
      socket.recv(message);
      resp_json.Deserialize(message.getData());
      if(SocketVerbose)
        {
         Print("response from server");
        }
     }
   else
     {
      if(SocketVerbose)
        {
         Print("no response from server");
        }
     }
  }
//+------------------------------------------------------------------+
