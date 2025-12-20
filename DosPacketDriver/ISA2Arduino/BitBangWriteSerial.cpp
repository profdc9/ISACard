/*
BitBangWriteSerial.cpp
*/
// 
// Includes
// 
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <Arduino.h>
#include "BitBangWriteSerial.h"


BitBangWriteSerial::BitBangWriteSerial(uint8_t pin, bool inverse_logic)
{
    txPin = pin;
    invLogic = inverse_logic;
}

void BitBangWriteSerial::begin(unsigned long speed)
{
    dly = ((uint32_t)1000000u)/((uint16_t)speed);
    pinMode(txPin, OUTPUT);
    digitalWrite(txPin, !invLogic);
}

void BitBangWriteSerial::end()
{
    pinMode(txPin, INPUT);
}

size_t BitBangWriteSerial::write(uint8_t c)
{
    cli();
    if (invLogic)
    {
        digitalWrite(txPin, HIGH);
        delayMicroseconds(dly);
        for (uint8_t bit=8;bit>0;bit--) {
            if (c & 0x01) 
                digitalWrite(txPin,LOW);
            else
                digitalWrite(txPin,HIGH);
            delayMicroseconds(dly);
            c>>=1;
        }
        digitalWrite(txPin, LOW);
        delayMicroseconds(dly);
    } else
    {
        digitalWrite(txPin, LOW);
        delayMicroseconds(dly);
        for (uint8_t bit=8;bit>0;bit--) {
            if (c & 0x01) 
                digitalWrite(txPin,HIGH);
            else
                digitalWrite(txPin,LOW);
            delayMicroseconds(dly);
            c>>=1;
        }
        digitalWrite(txPin, HIGH);
        delayMicroseconds(dly);
   }
   sei();
   return 1;
}

void BitBangWriteSerial::flush()
{
}

int BitBangWriteSerial::available()
{
    return 0;
}

int BitBangWriteSerial::peek()
{
    return -1;
}

int BitBangWriteSerial::read()
{
    return -1;
}

BitBangWriteSerial::~BitBangWriteSerial()
{
  end();
}
