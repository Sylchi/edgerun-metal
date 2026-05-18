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
typedef void* EFI_EVENT;
typedef void* EFI_PHYSICAL_ADDRESS;
typedef uint64_t EFI_STATUS;
typedef uint16_t EFI_KEY_T;
typedef uint8_t BOOLEAN;

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
typedef struct EFI_BOOT_SERVICES EFI_BOOT_SERVICES;
typedef struct EFI_SERVICE_BINDING_PROTOCOL EFI_SERVICE_BINDING_PROTOCOL;
typedef struct EFI_UDP4_PROTOCOL EFI_UDP4_PROTOCOL;
typedef struct EFI_GRAPHICS_OUTPUT_PROTOCOL EFI_GRAPHICS_OUTPUT_PROTOCOL;

typedef struct {
  UINT32 Data1;
  UINT16 Data2;
  UINT16 Data3;
  UINT8 Data4[8];
} EFI_GUID;

typedef struct {
  EFI_GUID VendorGuid;
  void* VendorTable;
} EFI_CONFIGURATION_TABLE;

typedef struct {
  UINT32 Revision;
  UINT32 HeaderSize;
  UINT32 CRC32;
  UINT32 Reserved;
  UINT64 Signature;
} EFI_TABLE_HEADER;

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

typedef enum {
  AllHandles = 0,
  ByRegisterNotify = 1,
  ByProtocol = 2
} EFI_LOCATE_SEARCH_TYPE;

typedef EFI_STATUS (*EFIAPI_CREATE_EVENT_FN)(UINT32 Type, UINTN NotifyTpl, void* NotifyFunction, void* NotifyContext, EFI_EVENT* Event);
typedef EFI_STATUS (*EFIAPI_CLOSE_EVENT_FN)(EFI_EVENT Event);
typedef EFI_STATUS (*EFIAPI_HANDLE_PROTOCOL_FN)(EFI_HANDLE Handle, EFI_GUID* Protocol, void** Interface);
typedef EFI_STATUS (*EFIAPI_LOCATE_HANDLE_BUFFER_FN)(EFI_LOCATE_SEARCH_TYPE SearchType, EFI_GUID* Protocol, void* SearchKey, UINTN* NoHandles, EFI_HANDLE** Buffer);
typedef EFI_STATUS (*EFIAPI_LOCATE_PROTOCOL_FN)(EFI_GUID* Protocol, void* Registration, void** Interface);
typedef EFI_STATUS (*EFIAPI_FREE_POOL_FN)(void* Buffer);
typedef EFI_STATUS (*EFIAPI_GET_MEMORY_MAP_FN)(UINTN* MemoryMapSize, void* MemoryMap, UINTN* MapKey, UINTN* DescriptorSize, UINT32* DescriptorVersion);
typedef EFI_STATUS (*EFIAPI_EXIT_BOOT_SERVICES_FN)(EFI_HANDLE ImageHandle, UINTN MapKey);

struct EFI_BOOT_SERVICES {
  EFI_TABLE_HEADER Hdr;
  void* RaiseTPL;
  void* RestoreTPL;
  void* AllocatePages;
  void* FreePages;
  EFIAPI_GET_MEMORY_MAP_FN GetMemoryMap;
  void* AllocatePool;
  EFIAPI_FREE_POOL_FN FreePool;
  EFIAPI_CREATE_EVENT_FN CreateEvent;
  void* SetTimer;
  void* WaitForEvent;
  void* SignalEvent;
  EFIAPI_CLOSE_EVENT_FN CloseEvent;
  void* CheckEvent;
  void* InstallProtocolInterface;
  void* ReinstallProtocolInterface;
  void* UninstallProtocolInterface;
  EFIAPI_HANDLE_PROTOCOL_FN HandleProtocol;
  void* Reserved;
  void* RegisterProtocolNotify;
  void* LocateHandle;
  void* LocateDevicePath;
  void* InstallConfigurationTable;
  void* LoadImage;
  void* StartImage;
  void* Exit;
  void* UnloadImage;
  EFIAPI_EXIT_BOOT_SERVICES_FN ExitBootServices;
  void* GetNextMonotonicCount;
  void* Stall;
  void* SetWatchdogTimer;
  void* ConnectController;
  void* DisconnectController;
  void* OpenProtocol;
  void* CloseProtocol;
  void* OpenProtocolInformation;
  void* ProtocolsPerHandle;
  EFIAPI_LOCATE_HANDLE_BUFFER_FN LocateHandleBuffer;
  EFIAPI_LOCATE_PROTOCOL_FN LocateProtocol;
};

typedef enum {
  PixelRedGreenBlueReserved8BitPerColor = 0,
  PixelBlueGreenRedReserved8BitPerColor = 1,
  PixelBitMask = 2,
  PixelBltOnly = 3,
  PixelFormatMax = 4
} EFI_GRAPHICS_PIXEL_FORMAT;

typedef struct {
  UINT32 RedMask;
  UINT32 GreenMask;
  UINT32 BlueMask;
  UINT32 ReservedMask;
} EFI_PIXEL_BITMASK;

typedef struct {
  UINT32 Version;
  UINT32 HorizontalResolution;
  UINT32 VerticalResolution;
  EFI_GRAPHICS_PIXEL_FORMAT PixelFormat;
  EFI_PIXEL_BITMASK PixelInformation;
  UINT32 PixelsPerScanLine;
} EFI_GRAPHICS_OUTPUT_MODE_INFORMATION;

typedef struct {
  UINT32 MaxMode;
  UINT32 Mode;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* Info;
  UINTN SizeOfInfo;
  UINT64 FrameBufferBase;
  UINTN FrameBufferSize;
} EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE;

typedef EFI_STATUS (*EFIAPI_GOP_QUERY_MODE_FN)(EFI_GRAPHICS_OUTPUT_PROTOCOL* This, UINT32 ModeNumber, UINTN* SizeOfInfo, EFI_GRAPHICS_OUTPUT_MODE_INFORMATION** Info);
typedef EFI_STATUS (*EFIAPI_GOP_SET_MODE_FN)(EFI_GRAPHICS_OUTPUT_PROTOCOL* This, UINT32 ModeNumber);

struct EFI_GRAPHICS_OUTPUT_PROTOCOL {
  EFIAPI_GOP_QUERY_MODE_FN QueryMode;
  EFIAPI_GOP_SET_MODE_FN SetMode;
  void* Blt;
  EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE* Mode;
};

typedef struct {
  UINT8 Addr[4];
} EFI_IPv4_ADDRESS;

typedef EFI_STATUS (*EFIAPI_SERVICE_BINDING_CREATE_CHILD_FN)(EFI_SERVICE_BINDING_PROTOCOL* This, EFI_HANDLE* ChildHandle);
typedef EFI_STATUS (*EFIAPI_SERVICE_BINDING_DESTROY_CHILD_FN)(EFI_SERVICE_BINDING_PROTOCOL* This, EFI_HANDLE ChildHandle);

struct EFI_SERVICE_BINDING_PROTOCOL {
  EFIAPI_SERVICE_BINDING_CREATE_CHILD_FN CreateChild;
  EFIAPI_SERVICE_BINDING_DESTROY_CHILD_FN DestroyChild;
};

typedef struct {
  BOOLEAN AcceptBroadcast;
  BOOLEAN AcceptPromiscuous;
  BOOLEAN AcceptAnyPort;
  BOOLEAN AllowDuplicatePort;
  UINT8 TypeOfService;
  UINT8 TimeToLive;
  BOOLEAN DoNotFragment;
  UINT32 ReceiveTimeout;
  UINT32 TransmitTimeout;
  BOOLEAN UseDefaultAddress;
  EFI_IPv4_ADDRESS StationAddress;
  EFI_IPv4_ADDRESS SubnetMask;
  UINT16 StationPort;
  EFI_IPv4_ADDRESS RemoteAddress;
  UINT16 RemotePort;
} EFI_UDP4_CONFIG_DATA;

typedef struct {
  EFI_IPv4_ADDRESS SourceAddress;
  UINT16 SourcePort;
  EFI_IPv4_ADDRESS DestinationAddress;
  UINT16 DestinationPort;
} EFI_UDP4_SESSION_DATA;

typedef struct {
  UINT32 FragmentLength;
  void* FragmentBuffer;
} EFI_UDP4_FRAGMENT_DATA;

typedef struct {
  EFI_UDP4_SESSION_DATA* UdpSessionData;
  EFI_IPv4_ADDRESS* GatewayAddress;
  UINT32 DataLength;
  UINT32 FragmentCount;
  EFI_UDP4_FRAGMENT_DATA FragmentTable[1];
} EFI_UDP4_TRANSMIT_DATA;

typedef union {
  void* RxData;
  EFI_UDP4_TRANSMIT_DATA* TxData;
} EFI_UDP4_COMPLETION_PACKET;

typedef struct {
  EFI_EVENT Event;
  EFI_STATUS Status;
  EFI_UDP4_COMPLETION_PACKET Packet;
} EFI_UDP4_COMPLETION_TOKEN;

typedef EFI_STATUS (*EFIAPI_UDP4_CONFIGURE_FN)(EFI_UDP4_PROTOCOL* This, EFI_UDP4_CONFIG_DATA* UdpConfigData);
typedef EFI_STATUS (*EFIAPI_UDP4_TRANSMIT_FN)(EFI_UDP4_PROTOCOL* This, EFI_UDP4_COMPLETION_TOKEN* Token);
typedef EFI_STATUS (*EFIAPI_UDP4_POLL_FN)(EFI_UDP4_PROTOCOL* This);

struct EFI_UDP4_PROTOCOL {
  void* GetModeData;
  EFIAPI_UDP4_CONFIGURE_FN Configure;
  void* Groups;
  void* Routes;
  EFIAPI_UDP4_TRANSMIT_FN Transmit;
  void* Receive;
  void* Cancel;
  EFIAPI_UDP4_POLL_FN Poll;
};

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
  EFI_BOOT_SERVICES* BootServices;
  UINTN NumberOfTableEntries;
  EFI_CONFIGURATION_TABLE* ConfigurationTable;
} EFI_SYSTEM_TABLE;

#define EFI_SUCCESS 0
#define EFI_ERROR_MASK 0x8000000000000000ull
#define EFI_BUFFER_TOO_SMALL ((EFI_STATUS)(EFI_ERROR_MASK | 5u))
#define EFI_NOT_READY ((EFI_STATUS)(EFI_ERROR_MASK | 6u))
#define EFI_INVALID_PARAMETER ((EFI_STATUS)(EFI_ERROR_MASK | 2u))
#define EVT_NOTIFY_SIGNAL 0x00000200u
#define TPL_CALLBACK 8u

#endif
