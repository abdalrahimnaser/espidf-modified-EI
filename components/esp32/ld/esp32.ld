/* ESP32 Linker Script Memory Layout

   This file describes the memory layout (memory blocks) as virtual
   memory addresses.

   esp32.project.ld contains output sections to link compiler output
   into these memory blocks.

   ***

   This linker script is passed through the C preprocessor to include
   configuration options.

   Please use preprocessor features sparingly! Restrict
   to simple macros with numeric values, and/or #if/#endif blocks.
*/
#include "sdkconfig.h"

/* If BT is not built at all */
#ifndef CONFIG_BT_RESERVE_DRAM
#define CONFIG_BT_RESERVE_DRAM 0
#endif

#if defined(CONFIG_ESP32_USE_FIXED_STATIC_RAM_SIZE)

ASSERT((CONFIG_ESP32_FIXED_STATIC_RAM_SIZE <= 0x2c200),
          "Fixed static ram data does not fit.")

#define DRAM0_0_SEG_LEN CONFIG_ESP32_FIXED_STATIC_RAM_SIZE

#else
#define DRAM0_0_SEG_LEN 0x2c200
#endif

#ifndef CONFIG_BOOTLOADER_RESERVE_RTC
#define CONFIG_BOOTLOADER_RESERVE_RTC 0
#endif

MEMORY
{
  /* All these values assume the flash cache is on, and have the blocks this uses subtracted from the length
  of the various regions. The 'data access port' dram/drom regions map to the same iram/irom regions but
  are connected to the data port of the CPU and eg allow bytewise access. */

  /* IRAM for PRO cpu. Not sure if happy with this, this is MMU area... */
  iram0_0_seg (RX) :                 org = 0x40080000, len = 0x20000-CONFIG_BOOTLOADER_RESERVE_RTC

  /* Even though the segment name is iram, it is actually mapped to flash
  */
  iram0_2_seg (RX) :                 org = 0x400D0018, len = 0x330000-0x18-CONFIG_BOOTLOADER_RESERVE_RTC

  /*
    (0x18 offset above is a convenience for the app binary image generation. Flash cache has 64KB pages. The .bin file
    which is flashed to the chip has a 0x18 byte file header. Setting this offset makes it simple to meet the flash
    cache MMU's constraint that (paddr % 64KB == vaddr % 64KB).)
  */


  /* Shared data RAM, excluding memory reserved for ROM bss/data/stack.

     Enabling Bluetooth & Trace Memory features in menuconfig will decrease
     the amount of RAM available.

     Note: Length of this section *should* be 0x50000, and this extra DRAM is available
     in heap at runtime. However due to static ROM memory usage at this 176KB mark, the
     additional static memory temporarily cannot be used.
  */
  dram0_0_seg (RW) :                 org = 0x3FFB0000 + CONFIG_BT_RESERVE_DRAM,
                                     len = DRAM0_0_SEG_LEN - CONFIG_BT_RESERVE_DRAM

  /* Flash mapped constant data */
  drom0_0_seg (R) :                  org = 0x3F400018, len = 0x400000-0x18

  /* (See iram0_2_seg for meaning of 0x18 offset in the above.) */

  /* RTC fast memory (executable). Persists over deep sleep.
   */
  rtc_iram_seg(RWX) :                org = 0x400C0000, len = 0x2000

  /* RTC fast memory (same block as above), viewed from data bus */
  rtc_data_seg(RW) :                 org = 0x3ff80000, len = 0x2000

  /* RTC slow memory (data accessible). Persists over deep sleep.

     Start of RTC slow memory is reserved for ULP co-processor code + data, if enabled.
  */
  rtc_slow_seg(RW)  :                org = 0x50000000 + CONFIG_ESP32_ULP_COPROC_RESERVE_MEM,
                                     len = 0x1000 - CONFIG_ESP32_ULP_COPROC_RESERVE_MEM

  /* external memory ,including data and text */
  extern_ram_seg(RWX)  :             org = 0x3F800000,
                                     len = 0x400000
}

#if defined(CONFIG_ESP32_USE_FIXED_STATIC_RAM_SIZE)
/* static data ends at defined address */
_static_data_end = 0x3FFB0000 + DRAM0_0_SEG_LEN;
#else
_static_data_end = _bss_end;
#endif

/* Heap ends at top of dram0_0_seg */
_heap_end = 0x40000000 - CONFIG_ESP32_TRACEMEM_RESERVE_DRAM;

_data_seg_org = ORIGIN(rtc_data_seg);

/* The lines below define location alias for .rtc.data section based on Kconfig option.
   When the option is not defined then use slow memory segment
   else the data will be placed in fast memory segment */
#ifndef CONFIG_ESP32_RTCDATA_IN_FAST_MEM
REGION_ALIAS("rtc_data_location", rtc_slow_seg );
#else
REGION_ALIAS("rtc_data_location", rtc_data_seg );
#endif
