// Check that the mstatus[SD] bit works as expected.

#include "common/encoding.h"
#include "common/runtime.h"

#include <stdbool.h>

bool sd_is_set()
{
  long mstatus;
  asm volatile("csrr %0, mstatus" : "=r"(mstatus));
  // SD is always the top bit.
  return mstatus < 0;
}

void clear_all_dirty_bits()
{
  unsigned long all = MSTATUS_FS | MSTATUS_VS | MSTATUS_XS;
  asm volatile("csrc mstatus, %0" : : "r"(all));
}

void set_fs()
{
  unsigned long fs = MSTATUS_FS;
  asm volatile("csrs mstatus, %0" : : "r"(fs));
}

void set_vs()
{
  unsigned long vs = MSTATUS_VS;
  asm volatile("csrs mstatus, %0" : : "r"(vs));
}

void set_xs()
{
  unsigned long xs = MSTATUS_XS;
  asm volatile("csrs mstatus, %0" : : "r"(xs));
}

int main()
{
  clear_all_dirty_bits();

  if (sd_is_set()) {
    printf("%s", "Error: SD was set when none of the FS/VS/XS bits were.\n");
    return 1;
  }

  clear_all_dirty_bits();
  set_fs();

  if (!sd_is_set()) {
    printf("%s", "Error: SD was not set when the FS bit was.\n");
    return 1;
  }
  // TODO: Actually we need to read the bits back because they could be
  // read-only.

  clear_all_dirty_bits();
  set_vs();

  if (!sd_is_set()) {
    printf("%s", "Error: SD was not set when the VS bit was.\n");
    return 1;
  }

  clear_all_dirty_bits();
  set_xs();

  // TODO: XS bit is not supported yet.
  // if (!sd_is_set()) {
  //   printf("%s", "Error: SD was not set when the XS bit was.\n");
  //   return 1;
  // }

  clear_all_dirty_bits();
  set_fs();
  set_vs();
  set_xs();

  if (!sd_is_set()) {
    printf("%s", "Error: SD was not set when all FS/VS/XS bits were.\n");
    return 1;
  }

  clear_all_dirty_bits();

  if (sd_is_set()) {
    printf("%s", "Error: SD was set when none of the FS/VS/XS bits were.\n");
    return 1;
  }

  return 0;
}
