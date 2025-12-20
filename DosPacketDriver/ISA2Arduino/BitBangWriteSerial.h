/*
BitBangWriteSerial.h 
*/

#ifndef BitBangWriteSerial_h
#define BitBangWriteSerial_h

#include <inttypes.h>
#include <Stream.h>

/******************************************************************************
* Definitions
******************************************************************************/

class BitBangWriteSerial : public Stream
{
private:
  uint8_t txPin;
  uint16_t dly;
  bool invLogic;
public:
  // public methods
  BitBangWriteSerial(uint8_t pin, bool inverse_logic = false);
  ~BitBangWriteSerial();
  void begin(unsigned long speed);
  void end();
  int peek();

  virtual size_t write(uint8_t byte);
  virtual int read();
  virtual int available();
  virtual void flush();
  operator bool() { return true; }
  
  using Print::write;
};

#endif
