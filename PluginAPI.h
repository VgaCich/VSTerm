#ifndef VSTERM_PLUGIN_API_H
#define VSTERM_PLUGIN_API_H

#include <Windows.h>

enum {
  TerminalAPIVersion = 2,
  PluginAPIVersion = 1
};

typedef struct Buffer { //For returning (string) data from functions
  char *Data; //Data
  int Len; //Data length
  void __stdcall (*Free)(struct Buffer *Self); //Destructor
} TBuffer;

typedef struct Plugin { //Plugin instance
  int Version; //Set to PluginAPIVersion
  char *Name; //Plugin name
  void __stdcall (*Free)(struct Plugin *Self); //Plugin destructor. Mandatory.
  void __stdcall (*Configure)(struct Plugin *Self); //Configure plugin (called when plugin's item in menu clicked). Optional.
  TBuffer* __stdcall (*OnReceive)(struct Plugin *Self, const char *Data, int Len); //Filter received data. Optional.
  TBuffer* __stdcall (*OnSend)(struct Plugin *Self, const char *Data, int Len); //Filter sent data. Optional.
} TPlugin;

typedef struct Terminal { //API, provided by host
  int Version; //API version, check to be no less than TerminalAPIVersion
  HWND WinHandle; //Host main window handle
  BOOL __stdcall (*SetEnabled)(struct Plugin *Plugin, BOOL Enable); //Enadle or disable plugin
  TBuffer* __stdcall (*GetOption)(const char *Section, const char *Key); //Get option from host's settings store
  void __stdcall (*SetOption)(const char *Section, const char *Key, const char *Value); //Write option to host's settings store
  void __stdcall (*AddToLog)(const char *Text, const char *Caption, int Color); //Write line to terminal log
  int __stdcall (*Send)(const char Data, int Len); //Send data to COM-port
} TTerminal;

TPlugin* __stdcall CreateVSTermPlugin(TTerminal *Terminal);

#endif
