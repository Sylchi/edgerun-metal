#ifndef ER_TYPES_H
#define ER_TYPES_H

#include <stdint.h>

typedef uint8_t UINT8;
typedef uint16_t UINT16;
typedef uint32_t UINT32;
typedef uint64_t UINT64;
typedef int8_t INT8;
typedef int16_t INT16;
typedef int32_t INT32;
typedef int64_t INT64;
typedef uint64_t UINTN;
typedef int64_t INTN;
typedef uint16_t CHAR16;
typedef void* EFI_HANDLE;
typedef void* EFI_PHYSICAL_ADDRESS;
typedef uint64_t EFI_STATUS;
typedef uint16_t EFI_KEY_T;

#ifndef EFIAPI
#if defined(_MSC_VER)
#define EFIAPI __cdecl
#elif defined(__GNUC__) || defined(__clang__)
#define EFIAPI __attribute__((ms_abi))
#else
#define EFIAPI
#endif
#endif

typedef struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
typedef struct EFI_SIMPLE_TEXT_INPUT_PROTOCOL EFI_SIMPLE_TEXT_INPUT_PROTOCOL;

typedef EFI_STATUS (*EFIAPI_CHAR16_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, const CHAR16*);
typedef EFI_STATUS (*EFIAPI_TEXT_RESET_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINT8);
typedef EFI_STATUS (*EFIAPI_TEXT_QUERY_MODE_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINTN, UINTN*, UINTN*);
typedef EFI_STATUS (*EFIAPI_TEXT_SET_MODE_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINTN);
typedef EFI_STATUS (*EFIAPI_TEXT_SET_ATTRIBUTE_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINTN);
typedef EFI_STATUS (*EFIAPI_TEXT_SIMPLE_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*);
typedef EFI_STATUS (*EFIAPI_TEXT_SET_CURSOR_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINTN, UINTN);
typedef EFI_STATUS (*EFIAPI_TEXT_ENABLE_CURSOR_FN)(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*, UINT8);

typedef struct {
  INT32 MaxMode;
  INT32 Mode;
  INT32 Attribute;
  INT32 CursorColumn;
  INT32 CursorRow;
  UINT8 CursorVisible;
} EFI_SIMPLE_TEXT_OUTPUT_MODE;

typedef struct {
  EFI_KEY_T ScanCode;
  CHAR16 UnicodeChar;
} EFI_INPUT_KEY;

typedef EFI_STATUS (*EFIAPI_KEY_FN)(EFI_SIMPLE_TEXT_INPUT_PROTOCOL*, EFI_INPUT_KEY*);

struct EFI_SIMPLE_TEXT_INPUT_PROTOCOL {
  void* Reset;
  EFIAPI_KEY_FN ReadKeyStroke;
  void* WaitForKey;
};

typedef struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
  EFIAPI_TEXT_RESET_FN Reset;
  EFIAPI_CHAR16_FN OutputString;
  void* TestString;
  EFIAPI_TEXT_QUERY_MODE_FN QueryMode;
  EFIAPI_TEXT_SET_MODE_FN SetMode;
  EFIAPI_TEXT_SET_ATTRIBUTE_FN SetAttribute;
  EFIAPI_TEXT_SIMPLE_FN ClearScreen;
  EFIAPI_TEXT_SET_CURSOR_FN SetCursorPosition;
  EFIAPI_TEXT_ENABLE_CURSOR_FN EnableCursor;
  EFI_SIMPLE_TEXT_OUTPUT_MODE* Mode;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

typedef struct {
  UINT32 Revision;
  UINT32 HeaderSize;
  UINT32 CRC32;
  UINT32 Reserved;
  UINT64 Signature;
} EFI_TABLE_HEADER;

typedef struct {
  EFI_TABLE_HEADER Hdr;
  CHAR16* FirmwareVendor;
  UINT32 FirmwareRevision;
  UINT32 Reserved;
  EFI_HANDLE ConsoleInHandle;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL* ConIn;
  EFI_HANDLE ConsoleOutHandle;
  EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* ConOut;
  EFI_HANDLE StandardErrorHandle;
  void* StdErr;
  void* RuntimeServices;
  void* BootServices;
  UINTN NumberOfTableEntries;
  void* ConfigurationTable;
} EFI_SYSTEM_TABLE;

#define EFI_SUCCESS 0

#endif
