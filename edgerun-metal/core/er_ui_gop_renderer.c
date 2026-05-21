#include "internal/er_ui_gop_renderer.h"

//@optimizer-ignore-constant UEFI GOP protocol GUID is ABI-defined by firmware
static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au}
};

static ErUiSurface g_surface;
static UINT8 g_ready;

#include "internal/er_ui_gop_backend.h"
