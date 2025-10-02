/* ISA2Arduino firmware */
/* by Daniel L. Marks */

/*
   Copyright (c) 2025 Daniel Marks

  This software is provided 'as-is', without any express or implied
  warranty. In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

/* Note to self to create objdump:

  C:\Users\dmarks\Documents\ArduinoData\packages\arduino\tools\avr-gcc\4.8.1-arduino5\bin\avr-objdump.exe -x -t -s Apple2Arduino.ino.elf > s155143
*/

#include <Arduino.h>
#include <avr/pgmspace.h>
#include <EEPROM.h>
#include "diskio_sdc.h"
#include "mmc_avr.h"
#include "ff.h"
#include "pindefs.h"

#define AVR_FLASH_STORE
#ifdef AVR_FLASH_STORE
#define PSTORE PROGMEM
#define strcpy_flash strcpy_P
#else
#define PSTORE
#define strcpy_flash strcpy
#endif

#undef USE_ETHERNET
#undef DEBUG_SERIAL
#define DEBUG_STATUS

#ifdef USE_ETHERNET
#include "w5500.h"
#endif

#ifdef DEBUG_SERIAL
#include <SoftwareSerial.h>
SoftwareSerial softSerial(SOFTWARE_SERIAL_RX, SOFTWARE_SERIAL_TX);
#define SERIALPORT() (&softSerial)
#endif

#define SD_SERVER_VERSION 0x0101

#define EEPROM_INIT 0
#define EEPROM_SLOT0 1
#define EEPROM_SLOT1 2

#define SLOT_STATE_NODEV 0
#define SLOT_STATE_BLOCKDEV 1
#define SLOT_STATE_FILEDEV 2

#ifdef USE_ETHERNET
uint8_t ethernet_initialized = 0;
Wiznet5500 eth(8);
#endif

typedef union _cmd_struct
{
  struct {
    uint8_t command;
    uint8_t drive_and_head;
    uint8_t count;
    uint8_t sector;
    uint16_t cylinder;
  } cylinder_head_sector;

  struct {
    uint8_t command;
    uint8_t bits_24;
    uint8_t count;
    uint8_t bits_00;
    uint8_t bits_08;
    uint8_t bits_16;
  } long_block_addressing;

  struct {
    uint8_t command;
    uint8_t drive_and_head;
    uint8_t count;
    uint8_t scan;
    uint16_t port_number;
  } inquire;

  uint8_t   b[6];
  uint16_t  w[3];
} cmd_struct;

typedef struct _drive_geometry
{
  uint16_t   cylinders;
  uint8_t    heads;
  uint8_t    sectors;
  uint32_t   sector_count;
} drive_geometry;

cmd_struct cs;

#define COMMAND_HEADER 0xa0

#define COMMAND_WRITE 1
#define COMMAND_READWRITE 2
#define COMMAND_RWMASK 3
#define COMMAND_INQUIRE 0

#define COMMAND_MASK 0xe3
#define COMMAND_HEADERMASK 0xe0

#define ATA_COMMAND_LBA 0x40
#define ATA_COMMAND_HEADMASK 0xf

#define ATA_DriveAndHead_Drive 0x10

FATFS   fs;
FIL     slotfile;
drive_geometry file_geometry;
uint8_t last_drive = 255;

uint8_t slot0_state = SLOT_STATE_NODEV;
uint8_t slot0_fileno;
drive_geometry slot0_geometry;

uint8_t slot1_state = SLOT_STATE_NODEV;
uint8_t slot1_fileno;
drive_geometry slot1_geometry;

static char blockvolzero[] = "0:";
static char blockvolone[] = "1:";

extern "C" {
  void write_string(const char *c)
  {
#ifdef DEBUG_SERIAL
    SERIALPORT()->print(c);
    SERIALPORT()->flush();
#endif
  }
}

void read_eeprom(void)
{
  if (EEPROM.read(EEPROM_INIT) != 255)
  {
    slot0_fileno = EEPROM.read(EEPROM_SLOT0);
    slot1_fileno = EEPROM.read(EEPROM_SLOT1);
  } else
  {
    slot0_fileno = 1;
    slot1_fileno = 1;
  }
}

void write_eeprom(void)
{
  if (EEPROM.read(EEPROM_SLOT0) != slot0_fileno)
    EEPROM.write(EEPROM_SLOT0, slot0_fileno);
  if (EEPROM.read(EEPROM_SLOT1) != slot1_fileno)
    EEPROM.write(EEPROM_SLOT1, slot1_fileno);
  if (EEPROM.read(EEPROM_INIT) == 255)
    EEPROM.write(EEPROM_INIT, 0);
}

void setup_pins(void)
{
  INITIALIZE_CONTROL_PORT();
  DISABLE_RXTX_PINS();
  DATAPORT_MODE_RECEIVE();
}

void setup_serial(void)
{
  Serial.end();
  DISABLE_RXTX_PINS();
#ifdef DEBUG_SERIAL
#ifdef SOFTWARE_SERIAL
  softSerial.begin(9600);
  pinMode(SOFTWARE_SERIAL_RX, INPUT);
  pinMode(SOFTWARE_SERIAL_TX, OUTPUT);
#endif
#endif
}

void write_dataport(uint8_t ch)
{
  while (READ_IBFA() != 0);
  DATAPORT_MODE_TRANS();
  WRITE_DATAPORT(ch);
  STB_LOW();
  STB_HIGH();
  DATAPORT_MODE_RECEIVE();
}

uint8_t read_dataport(void)
{
  uint8_t byt;

  while (READ_OBFA() != 0);
  ACK_LOW();
  byt = READ_DATAPORT();
  ACK_HIGH();
  return byt;
}

inline void inline_write_dataport(uint8_t ch)
{
  while (READ_IBFA() != 0);
  DATAPORT_MODE_TRANS();
  WRITE_DATAPORT(ch);
  STB_LOW();
  STB_HIGH();
  DATAPORT_MODE_RECEIVE();
}

inline uint8_t inline_read_dataport(void)
{
  uint8_t byt;

  while (READ_OBFA() != 0);
  ACK_LOW();
  byt = READ_DATAPORT();
  ACK_HIGH();
  return byt;
}

uint8_t hex_digit(uint8_t ch)
{
  if (ch < 10) return ch + '0';
  return ch - 10 + 'A';
}

const char blockdev_filename_prototype[] PSTORE="0:BLKDEVXX.IMG";

void blockdev_filename(char *blockdev_filename, uint8_t drive_no, uint8_t fileno)
{
  strcpy_flash(blockdev_filename, blockdev_filename_prototype);
  blockdev_filename[0] = drive_no + '0';
  blockdev_filename[8] = hex_digit(fileno >> 4);
  blockdev_filename[9] = hex_digit(fileno & 0x0F);  
}

bool geometry_to_chs(drive_geometry *dg)
{
  if (dg->sector_count <= 65536)      // try to do something sensible for early MSDOS
  { // (< 32 MB hard disks)
    dg->sectors = 17;
    dg->heads = 4;
    dg->cylinders = dg->sector_count / (17 * 4);
    dg->sector_count = ((uint32_t)dg->cylinders) * (17 * 4); // truncate sector count to accessible sectors
    return true;
  }
  if (dg->sector_count <= 1032912)    // if we fit within 504 MB
  {
    dg->heads = 16;
    dg->sectors = 63;
    dg->cylinders = dg->sector_count / (16 * 63);
    dg->sector_count = ((uint32_t)dg->cylinders) * (16 * 63); // truncate sector count to accessible sectors
    return true;
  }
  if (dg->sector_count < 16450560)
  {
    dg->heads = 255;                     // full int13h limit to 8.4 GB
    dg->sectors = 63;
    dg->cylinders = dg->sector_count / (255 * 63);
    dg->sector_count = ((uint32_t)dg->cylinders) * (255 * 63); // truncate sector count to accessible sectors
    return true;
  }
  dg->heads = 0;
  dg->sectors = 0;
  dg->cylinders = 0;
  return false;  // sizes above this are LBA only
}

static uint8_t filesystem_initialized[2];

uint8_t check_change_filesystem(uint8_t current_filesystem)
{
  if (last_drive == current_filesystem)
    return 1;

  if (last_drive < 2)
  {
    f_close(&slotfile);
    f_unmount(last_drive == 0 ? blockvolzero : blockvolone);
  }
  last_drive = 255;
  if (current_filesystem < 2)
  {
    if (!filesystem_initialized[current_filesystem])
    {
        disk_initialize(current_filesystem);
        filesystem_initialized[current_filesystem] = 1;
    }
    if (f_mount(&fs, current_filesystem == 0 ? blockvolzero : blockvolone, 0) == FR_OK)
    {
      char filename[20];
      blockdev_filename(filename, current_filesystem, current_filesystem == 0 ? slot0_fileno : slot1_fileno);
      if (f_open(&slotfile, filename, FA_READ | FA_WRITE) == FR_OK)
      {
        file_geometry.sector_count = f_size(&slotfile) >> 9;  // divide by 512 for sector count
        geometry_to_chs(&file_geometry);
        last_drive = current_filesystem;
        return 1;
      }
      f_close(&slotfile);
    }
    f_unmount(current_filesystem == 0 ? blockvolzero : blockvolone);
  }
  return 0;
}

void initialize_drive(uint8_t cardslot)
{
  if (cardslot)
  {
    if (slot1_state == SLOT_STATE_NODEV)
    {
      if (slot1_fileno == 0)
      {
        if (disk_initialize(1) == 0)
        {
          if (mmc_disk_ioctl(GET_SECTOR_COUNT, &slot1_geometry.sector_count) == 0)
          {
            geometry_to_chs(&slot1_geometry);
            slot1_state = SLOT_STATE_BLOCKDEV;
          }
        }
      } else
      {
        check_change_filesystem(255);
        if (check_change_filesystem(1))
          slot1_state = SLOT_STATE_FILEDEV;
      }
    }
  } else
  {
    if (slot0_state == SLOT_STATE_NODEV)
    {
      if (slot0_fileno == 0)
      {
        if (disk_initialize(0) == 0)
        {
          if (mmc_disk_ioctl(GET_SECTOR_COUNT, &slot0_geometry.sector_count) == 0)
          {
            geometry_to_chs(&slot0_geometry);
            slot0_state = SLOT_STATE_BLOCKDEV;
          }
        }
      } else
      {
        check_change_filesystem(255);
        if (check_change_filesystem(0))
          slot0_state = SLOT_STATE_FILEDEV;
      }
    }
  }
}

void unmount_drive(uint8_t cardslot)
{
  if (cardslot)
  {
    switch (slot1_state)
    {
      case SLOT_STATE_NODEV:
        return;
      case SLOT_STATE_BLOCKDEV:
        slot1_state = SLOT_STATE_NODEV;
        return;
      case SLOT_STATE_FILEDEV:
        check_change_filesystem(255);
        slot1_state = SLOT_STATE_NODEV;
        return;
    }
  } else
  {
    switch (slot0_state)
    {
      case SLOT_STATE_NODEV:
        return;
      case SLOT_STATE_BLOCKDEV:
        slot0_state = SLOT_STATE_NODEV;
        return;
      case SLOT_STATE_FILEDEV:
        check_change_filesystem(255);
        slot0_state = SLOT_STATE_NODEV;
        return;
    }
  }
}

#ifdef USE_ETHERNET
void do_initialize_ethernet(void)
{
  uint8_t mac_address[6];
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("initialize ethernet");
#endif
  for (uint8_t i = 0; i < 6; i++)
  {
    mac_address[i] = read_dataport();
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->print(mac_address[i], HEX);
    SERIALPORT()->print(" ");
#endif
  }
  if (ethernet_initialized)
    eth.end();
  if (eth.begin(mac_address))
  {
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->println("initialized");
#endif
    ethernet_initialized = 1;
    write_dataport(0);
    return 0;
  }
#ifdef DEBUG_SERIAL
  SERIALPORT()->println("not initialized");
#endif
  ethernet_initialized = 0;
  write_dataport(1);
  return 1;
}

void do_poll_ethernet(void)
{
  uint16_t len;
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("poll eth");
#endif
  if (ethernet_initialized)
  {
    len = read_dataport();
    len |= ((uint16_t)read_dataport()) << 8;
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->print("read len ");
    SERIALPORT()->println(len, HEX);
#endif
    len = eth.readFrame(NULL, len);
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->print("recv len ");
    SERIALPORT()->println(len, HEX);
#endif
  } else
  {
    write_dataport(0);
    write_dataport(0);
  }
}

void do_send_ethernet(void)
{
  uint16_t len;
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("send eth");
#endif
  if (ethernet_initialized)
  {
    len = read_dataport();
    len |= ((uint16_t)read_dataport()) << 8;
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->print("len ");
    SERIALPORT()->println(len, HEX);
#endif
    eth.sendFrame(NULL, len);
  }
  write_dataport(0);
}
#endif

int freeRam ()
{
  extern int __heap_start, *__brkval;
  int v;
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}

void setup()
{
  setup_pins();
  setup_serial();
  read_eeprom();

  power_on();  // hack to disable SPI pins temporarily
  //initialize_drive(1);
  //initialize_drive(0);

#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("0000");
  SERIALPORT()->print("d=");
  SERIALPORT()->print(sizeof(fs));
  SERIALPORT()->print(" f=");
  SERIALPORT()->print(freeRam());
  SERIALPORT()->print(" s=");
  SERIALPORT()->print(slot0_fileno);
  SERIALPORT()->print(" ");
  SERIALPORT()->println(slot1_fileno);
#endif

  DATAPORT_MODE_RECEIVE();
}

inline uint32_t lba_sector_from_chs(const drive_geometry *dg)
{
  uint32_t sector = (((((uint32_t)(dg->heads)) * cs.cylinder_head_sector.cylinder) +
                      (cs.cylinder_head_sector.drive_and_head & ATA_COMMAND_HEADMASK)) * 
                      ((uint32_t)(dg->sectors))) + cs.cylinder_head_sector.sector - 1;
  return sector;
}

void transmit_512_bytes(uint8_t *b)
{
  cli();
  DATAPORT_MODE_TRANS();
  uint16_t i = 512;
  do
  {
    while (READ_IBFA() != 0);
    WRITE_DATAPORT(*b++);
    STB_LOW();
    STB_HIGH();
  } while ((--i) != 0);
  DATAPORT_MODE_RECEIVE();
  sei();
}

void transmit_512_zeros(void)
{
  cli();
  DATAPORT_MODE_TRANS();
  uint16_t i = 512;
  do
  {
    while (READ_IBFA() != 0);
    WRITE_DATAPORT(0);
    STB_LOW();
    STB_HIGH();
  } while ((--i) != 0);
  DATAPORT_MODE_RECEIVE();
  sei();
}

void receive_512_bytes(uint8_t *b)
{
  cli();
  uint16_t i = 512;
  do
  {
    while (READ_OBFA() != 0);
    ACK_LOW();
    *b++ = READ_DATAPORT();
    ACK_HIGH();
  } while ((--i) != 0);
  sei();
}

void receive_and_discard_512_bytes(void)
{
  cli();
  uint16_t i = 512;
  do
  {
    while (READ_OBFA() != 0);
    ACK_LOW();
    READ_DATAPORT();
    ACK_HIGH();
  } while ((--i) != 0);
  sei();
}

void error_condition(uint8_t masked_command)
{
  if (masked_command & 0x01)
  {
    for (uint8_t i=0; i<cs.cylinder_head_sector.count; i++)
         receive_and_discard_512_bytes();    
  } else  // this is suppose to be a read command
  {
    for (uint8_t i=0; i<cs.cylinder_head_sector.count; i++)
         transmit_512_zeros();
  }
  write_dataport(0x01);           // write a one which indicates an error       
}

#define ATA_wGenCfg 0
#define ATA_wCylCnt 1
#define ATA_wHeadCnt 3
#define ATA_wBpTrck 4
#define ATA_wBpSect 5
#define ATA_wSPT 6

#define ATA_strSD 10
#define ATA_strSD_Length 20

#define ATA_strFirmware 23
#define ATA_strFirmware_Length 8

#define ATA_strModel 27
#define ATA_strModel_Length 40                 // Maximum allowable length of the string according to the ATA spec
#define XTIDEBIOS_strModel_Length 30           // Maximum length copied out of the ATA information by the BIOS

#define ATA_wCaps 49
#define ATA_wCurCyls 54
#define ATA_wCurHeads 55
#define ATA_wCurSPT 56
#define ATA_dwCurSCnt 57
#define ATA_dwLBACnt 60

// Words carved out of the vendor specific area for our use
//
#define ATA_wSDServerVersion 157
#define ATA_wSDDriveFlags 158
#define ATA_wPortIO8255 159

// Defines used in the words above
//
#define ATA_wCaps_LBA 0x200

#define ATA_wGenCfg_FIXED 0x40

#define ATA_wSDDriveFlags_Present   0x08

void flip_words(uint16_t *words, uint8_t n)
{
  while (n>0)
   {
      uint16_t temp = *words;
      *words++ = ((temp & 0xFF00) >> 8) | ((temp & 0x00FF) << 8);
      n--;
   }
}

const uint8_t strModel[] PSTORE = "SD Card";
const uint8_t strSD[] PSTORE = "Number X";
const uint8_t strFirmware[] PSTORE = "Ver X.X";

void command_inquire(uint8_t drive)
{
  uint16_t response_buffer[256];

  unmount_drive(drive);
  initialize_drive(drive);
  if (((drive != 0) && (slot1_state == SLOT_STATE_NODEV)) || ((drive == 0) && (slot0_state == SLOT_STATE_NODEV)))
  {
#ifdef DEBUG_SERIAL
    SERIALPORT()->println("drive not initialized");
#endif
    error_condition(0);
    return;
  }

  drive_geometry *dg;

  if (drive)
    dg = (slot1_state == SLOT_STATE_FILEDEV) ? &file_geometry : &slot1_geometry;
  else
    dg = (slot0_state == SLOT_STATE_FILEDEV) ? &file_geometry : &slot0_geometry;

#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->print("states ");
  SERIALPORT()->print(slot0_state);
  SERIALPORT()->println(slot1_state);
#endif

  memset((void *)response_buffer, '\000', sizeof(response_buffer));
  
  strcpy_flash((char *)&response_buffer[ATA_strModel], strModel);
  flip_words(&response_buffer[ATA_strModel], ATA_strModel_Length/2);

  strcpy_flash((char *)&response_buffer[ATA_strSD], strSD);
  ((uint8_t *)response_buffer)[ATA_strSD*2+6] = (drive != 0) + '0';
  flip_words(&response_buffer[ATA_strSD], ATA_strSD_Length/2);

  strcpy_flash((char *)&response_buffer[ATA_strFirmware], strFirmware);
  flip_words(&response_buffer[ATA_strFirmware], ATA_strFirmware_Length/2);

  response_buffer[ATA_wCylCnt] = dg->cylinders;
  response_buffer[ATA_wHeadCnt] = dg->heads;
  response_buffer[ATA_wSPT] = dg->sectors;

  if (dg->heads == 0)   // must be LBA
  {
    response_buffer[ATA_wCaps] = ATA_wCaps_LBA;
    response_buffer[ATA_dwLBACnt] = (uint16_t) (dg->sector_count & 0xFFFF);
    response_buffer[ATA_dwLBACnt+1] = (uint16_t) ((dg->sector_count & 0xFFFF0000) >> 16);
  }

  response_buffer[ATA_wSDServerVersion] = SD_SERVER_VERSION;
  response_buffer[ATA_wSDDriveFlags] = ATA_wSDDriveFlags_Present;
  response_buffer[ATA_wPortIO8255] = cs.inquire.port_number;
  response_buffer[ATA_wGenCfg] = ATA_wGenCfg_FIXED;
  transmit_512_bytes((uint8_t *)response_buffer);
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->println("transmitted response buffer");
#endif
  write_dataport(0x0);

#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->print("geometry ");
  SERIALPORT()->print(response_buffer[ATA_wCylCnt]);
  SERIALPORT()->print("/");
  SERIALPORT()->print(response_buffer[ATA_wHeadCnt]);
  SERIALPORT()->print("/");
  SERIALPORT()->print(response_buffer[ATA_wSPT]);
  SERIALPORT()->print("/");
  SERIALPORT()->print(response_buffer[ATA_wCaps]);
  SERIALPORT()->print("/");
  SERIALPORT()->println(dg->sector_count);  
#endif
}

void loop()
{
  uint8_t instr = inline_read_dataport();
  if (instr == 0xEE)              // special instrant command code
  {
    write_dataport(0x47);
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("g0xEE");
#endif
    return;
  }
  if (instr == 0xED)              // special instrant command code
  {
    write_dataport(0x9C);
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->println("g0xED");
#endif
    return;
  }
  if ((instr & 0xE8) != 0xA0)
  {
#ifdef DEBUG_SERIAL
  SERIALPORT()->print("badcmd ");
  SERIALPORT()->println(instr);
#endif
     return;    
  }
  cs.b[0] = instr;
  cs.b[1] = inline_read_dataport();
  cs.b[2] = inline_read_dataport();
  cs.b[3] = inline_read_dataport();
  cs.b[4] = inline_read_dataport();
  cs.b[5] = inline_read_dataport();

  uint8_t drive = (cs.inquire.drive_and_head & ATA_DriveAndHead_Drive) != 0;
  uint8_t masked_command = cs.cylinder_head_sector.command & COMMAND_RWMASK;
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
  SERIALPORT()->print("cmd ");
  SERIALPORT()->print(cs.cylinder_head_sector.command);
  SERIALPORT()->print(" ");
  SERIALPORT()->print(drive);
  SERIALPORT()->print(" ");
  SERIALPORT()->println(masked_command);
#endif
  if (masked_command == COMMAND_INQUIRE)
  {
    command_inquire(drive);
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->println("inquire");
#endif
    return;
  }
  if (((drive != 0) && (slot1_state == SLOT_STATE_NODEV)) || ((drive == 0) && (slot0_state == SLOT_STATE_NODEV)))
  {
    error_condition(masked_command);
#ifdef DEBUG_SERIAL
    SERIALPORT()->println("inactive");
#endif
    return;
  }

  drive_geometry *dg;
  if (drive)
    dg = (slot1_state == SLOT_STATE_FILEDEV) ? &file_geometry : &slot1_geometry;
  else
    dg = (slot0_state == SLOT_STATE_FILEDEV) ? &file_geometry : &slot0_geometry;

  uint32_t lba_sector;
  if (cs.cylinder_head_sector.drive_and_head & ATA_COMMAND_LBA)
  {
      lba_sector = ((((uint32_t)cs.long_block_addressing.bits_24) & ATA_COMMAND_HEADMASK) << 24) |
                   (((uint32_t)cs.long_block_addressing.bits_16) << 16) |
                   (((uint32_t)cs.long_block_addressing.bits_08) << 8) |
                   (((uint32_t)cs.long_block_addressing.bits_00));
  } else
      lba_sector = lba_sector_from_chs(dg);
  if ((lba_sector + cs.cylinder_head_sector.count) > dg->sector_count)
  {
    error_condition(masked_command);
#ifdef DEBUG_SERIAL
    SERIALPORT()->print("invalid lba ");
    SERIALPORT()->println(lba_sector);
#endif
    return;
  }
#if defined(DEBUG_SERIAL) && defined(DEBUG_STATUS)
    SERIALPORT()->print("chs");
    SERIALPORT()->print(cs.cylinder_head_sector.cylinder);
    SERIALPORT()->print(" ");
    SERIALPORT()->print(cs.cylinder_head_sector.drive_and_head & ATA_COMMAND_HEADMASK);
    SERIALPORT()->print(" ");
    SERIALPORT()->print(cs.cylinder_head_sector.sector);
    SERIALPORT()->print(" ");
    SERIALPORT()->print(cs.cylinder_head_sector.count);
    SERIALPORT()->print(" ");
    SERIALPORT()->println(lba_sector);
#endif
  if ( ((drive != 0) && (slot1_state == SLOT_STATE_FILEDEV)) || ((drive == 0) && (slot0_state == SLOT_STATE_FILEDEV)) )
  {
      if ((!check_change_filesystem(drive)) || (f_lseek(&slotfile, lba_sector << 9) != FR_OK))
      {
          error_condition(masked_command);
#ifdef DEBUG_SERIAL
          SERIALPORT()->println("file error");
#endif
          return;
      }
      uint8_t count_sectors = cs.cylinder_head_sector.count;
      if (masked_command & 0x01)
      {
          while (count_sectors > 0)
          {
            count_sectors--;
            uint8_t buf[512];
            uint16_t br;
            receive_512_bytes(buf);
            if ((f_write(&slotfile, buf, 512, &br) != FR_OK) || (br != 512))
            {
                cs.cylinder_head_sector.count = count_sectors;
                error_condition(masked_command);
#ifdef DEBUG_SERIAL
                SERIALPORT()->println("file write error");
#endif
                return;        
            }
          }
          write_dataport(0x0);
          return;
      } else
      {
          while (count_sectors > 0)
          {
            count_sectors--;
            uint8_t buf[512];
            uint16_t br;
            if ((f_read(&slotfile, buf, 512, &br) != FR_OK) || (br != 512))
            {
                cs.cylinder_head_sector.count = count_sectors;
                error_condition(masked_command);
#ifdef DEBUG_SERIAL
                SERIALPORT()->println("file read error");
#endif
                return;        
            }
            transmit_512_bytes(buf);
          }
          write_dataport(0x0);
          return;
      }
  }
  uint8_t count_sectors = cs.cylinder_head_sector.count;
  if (masked_command & 0x01)
  {
      while (count_sectors > 0)
      {
         count_sectors--;
         uint8_t buf[512];
         uint16_t br;
         receive_512_bytes(buf);
         if (disk_write(drive, buf, lba_sector, 1) != 0)
         {
             cs.cylinder_head_sector.count = count_sectors;
             error_condition(masked_command);
#ifdef DEBUG_SERIAL
                SERIALPORT()->println("disk write error");
#endif
             return;        
         }
      }
      write_dataport(0x0);
      return;
   } else
   {
      while (count_sectors > 0)
      {
        count_sectors--;
        uint8_t buf[512];
        uint16_t br;
        if (disk_read(drive, buf, lba_sector, 1) != 0)
        {
             cs.cylinder_head_sector.count = count_sectors;
             error_condition(masked_command);
#ifdef DEBUG_SERIAL
                SERIALPORT()->println("disk read error");
#endif

             return;        
        }
        transmit_512_bytes(buf);
      }
      write_dataport(0x0);
      return;
   }
}
