#ifndef ER_EFI_BOOT_INTERNAL_H
#define ER_EFI_BOOT_INTERNAL_H

#include "er_types.h"
#include "er_print.h"
#include "er_pci.h"
#include "er_mmio.h"
#include "er_mem.h"
#include "er_netlog.h"
#include "er_app.h"
#include "er_crypto_blake3.h"
#include "er_acpi.h"
#include "er_boot_efi_vars.h"
#include "er_boot_profile.h"
#include "er_boot_services.h"
#include "er_ble_adv.h"
#include "er_gfx_console.h"
#include "er_ps2_keyboard.h"
#include "er_native_boot.h"
#include "er_render_endpoint.h"
#include "er_storage_endpoint.h"
#include "er_ui_surface_renderer.h"
#include "er_ui_components.h"
#include "er_ui_ledger_app.h"
#include "er_ui_metal.h"
#include "er_ui_theme.h"
#include "er_ui_wasm_app.h"
#include "er_virtio_gpu.h"
#include "font_geist.h"
#include "wasm_vm.h"
#include "wasm_user_app_module.h"
#include "app_user_manifest.h"

#ifndef ER_BOOT_PROFILE
#define ER_BOOT_PROFILE ER_BOOT_PROFILE_OS
#endif

#define ER_CONSOLE_MIN_COLUMNS 80u
#define ER_CONSOLE_MIN_ROWS 25u
#define ER_UI_BOOT_ARENA_SIZE (4u * 1024u * 1024u)
#define ER_UI_BOOT_ARENA_FREE_BLOCKS 256u
#define ER_UI_BOOT_TILE_WIDTH 128u
#define ER_UI_BOOT_TILE_HEIGHT 64u
#define ER_UI_BOOT_MAX_DIRTY_TILES 4096u
#define ER_UI_BOOT_MAX_TILE_MARKS 8192u
#define ER_UI_BOOT_RENDER_OVERDRAW_BUDGET 4u
#define ER_UI_BOOT_BACKING_BUFFERS 1u
#define ER_UI_BOOT_LOW_HEIGHT_MAX 1200u
#define ER_UI_BOOT_SMALL_FONT_PX 16.0f
#define ER_UI_BOOT_LARGE_FONT_PX 28.0f
#define ER_UI_BOOT_FONT_ATLAS_SIZE 1024u
#define ER_UI_BOOT_FONT_ATLAS_PAD 2u
#define ER_UI_BOOT_COMMAND_BYTES (256u * 1024u)
#define ER_UI_BOOT_GLYPH_CACHE_BYTES (1024u * 1024u)
#define ER_UI_BOOT_SURFACE_BYTES 0u
#define ER_UI_BOOT_MEMORY_BUDGET_BYTES (128u * 1024u * 1024u)
#define ER_EFI_MEMORY_MAP_BYTES (128u * 1024u)
#define ER_EFI_EXIT_BOOT_SERVICES_ATTEMPTS 2u
#define ER_WASM_DRIVER_MEMORY_BYTES (64u * 1024u)
#define ER_UI_BOOT_APP_SLOT_CAPACITY 2u
#define ER_UI_BOOT_INSTALLED_APP_COUNT 1u
#define ER_UI_BOOT_APP_MEMORY_BYTES (64u * 1024u)
#define ER_UI_BOOT_APP_MODULE_BYTES 1024u
#define ER_UI_BOOT_APP_MANIFEST_BYTES 256u
#define ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY 1u
#define ER_UI_WASM_RELAY_INBOX_BASE 0u
#define ER_UI_WASM_RELAY_INBOX_BYTES 1024u
#define ER_UI_WASM_RELAY_OUTBOX_BASE 1024u
#define ER_UI_WASM_RELAY_OUTBOX_BYTES 2048u
#define ER_UI_WASM_PRESENTATION_SEQUENCE 1u
#define ER_UI_WASM_PRESENTATION_ID_SEED 0x10u
#define ER_UI_WASM_JURISDICTION_ID_SEED 0x30u
#define ER_UI_WASM_ADMISSION_ID_SEED 0x50u
#define ER_UI_WASM_APP_NODE_ID_SEED 0x70u
#define ER_UI_WASM_RELAY_NODE_ID_SEED 0x90u
#define ER_UI_WASM_ROUTE_HASH_SEED 0xb0u
#define ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED 0xc0u
#define ER_UI_WASM_STORAGE_MANIFEST_ROUTE_ID_SEED 0xd0u
#define ER_UI_WASM_STORAGE_REQUEST_HASH_OFFSET 1u
#define ER_UI_WASM_STORAGE_ADMISSION_HASH_OFFSET 2u
#define ER_UI_WASM_STORAGE_SOURCE_NODE_OFFSET 3u
#define ER_UI_WASM_STORAGE_TARGET_NODE_OFFSET 4u
#define ER_UI_WASM_STORAGE_RELAY_NODE_OFFSET 5u
#define ER_UI_WASM_STORAGE_CHANNEL_ID_OFFSET 6u
#define ER_UI_WASM_STORAGE_ROUTE_COMMITMENT_OFFSET 7u
#define ER_UI_WASM_STORAGE_ROUTE_BUDGET 2u
#define ER_UI_WASM_APP_SEED_STRIDE 0x10u
#define ER_UI_WASM_PS2_INPUT_EPOCH_STRIDE 1u
#define ER_UI_WASM_EXECUTE_EPOCH_STRIDE 2u
#define ER_UI_WASM_COUNTER_PACKET_BYTES (ER_WASM_UI_COMMAND_LIST_HEADER_LEN + \
                                         ER_WASM_UI_RECT_RECORD_LEN + \
                                         ER_WASM_UI_HIT_RECORD_LEN + \
                                         ER_WASM_UI_QUAD_RECORD_LEN)
#define ER_ACPI_SIGNATURE_BYTES 4u
#define ER_BYTE_MASK 0xffu
#define ER_GPU_PROFILE_POLL_LIMIT 1000000u
#define ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX 1920u
#define ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX 1080u
#define ER_GPU_PROFILE_FRAMEBUFFER_WIDTH 1920u
#define ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT 1080u
#define ER_GPU_PROFILE_RESOURCE_ID 1u
#define ER_GPU_PROFILE_SCANOUT_ID 0u
#define ER_UI_BOOT_GPU_RESOURCE_ID 2u
#define ER_UI_BOOT_GPU_SCANOUT_ID 0u
#define ER_GPU_PROFILE_TOP_COLOR 0x0040d0e0u
#define ER_GPU_PROFILE_BOTTOM_COLOR 0x00202020u
#define ER_TPM_PROFILE_COMMAND_BYTES 128u
#define ER_TPM_PROFILE_RESPONSE_BYTES 512u
#define ER_TPM_PROFILE_RANDOM_REQUEST_BYTES 16u
#define ER_TPM_PROFILE_DIGEST_BYTES 32u
#define ER_TPM_PROFILE_SIGNATURE_BYTES 64u
#define ER_BOOT_DEFAULT_ADMISSION_GENERATION 1u
#define ER_BOOT_BLE_ADV_SEQUENCE 1u
#define ER_BOOT_BLE_WIFI_GROUP_ID 0x45525746u
#define ER_BOOT_BLE_WIFI_NODE_NONCE 0x4544474552554e31ull
#define ER_BOOT_BLE_WIFI_CHANNEL 6u
#define ER_BOOT_BLE_WIFI_PRIORITY 1u
#define ER_BOOT_BYTE_BITS 8u
enum {
  ER_LOG_U64_STAGE_IDLE = 0u,
  ER_LOG_U64_STAGE_PCI_FIELDS = 3u,
  ER_LOG_HEX_STAGE_ID = 0u,
  ER_LOG_HEX_STAGE_COMMAND_STATUS = 1u,
  ER_LOG_HEX_STAGE_CLASS_REVISION = 2u,
  ER_LOG_HEX_STAGE_HEADER_CACHELINE = 3u,
  ER_LOG_HEX_STAGE_BAR0 = 4u,
  ER_LOG_HEX_STAGE_BAR1 = 5u,
  ER_LOG_HEX_STAGE_BAR2 = 6u,
  ER_LOG_HEX_STAGE_BAR3 = 7u,
  ER_LOG_HEX_STAGE_BAR4 = 8u,
  ER_LOG_HEX_STAGE_BAR5 = 9u
};

typedef struct {
  ErStorageEndpointObjectStore app_store;
  ErStorageEndpointObjectStore manifest_store;
  ErVfsObjectPacket app_packets[ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY];
  ErVfsObjectPacket manifest_packets[ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY];
} ErUiBootPackageStorage;

typedef struct {
  const char* app_label;
  UINTN app_label_len;
  const UINT8* app_bytes;
  UINTN app_len;
  const char* manifest_label;
  UINTN manifest_label_len;
  const UINT8* manifest_bytes;
  UINTN manifest_len;
} ErUiBootInstalledApp;

typedef struct {
  ErAppUiPresentation presentation;
  ErUiWasmAppRuntime runtime;
  ErUiBootPackageStorage storage;
  er_ui_scene_t scene;
  UINT8 ready;
} ErUiBootAppContext;

typedef struct {
  UINT64 polls;
  UINT64 none;
  UINT64 malformed;
  UINT64 unsupported;
  UINT64 render_capability;
  UINT64 render_scenes;
  UINT64 storage_object_packets;
  UINT64 transit_hops;
  UINT64 transit_emitted;
} ErUiBootNativeRelayStats;

typedef struct {
  vr_font_face_t* font;
  ErUiSurfaceMode mode;
  ErUiSurface* surface;
  ErVirtioGpu* gpu;
  const ErVirtioGpuFramebuffer* framebuffer;
  const ErUiSurfaceTilePlan* tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  er_ui_scene_budget_t scene_budget;
  ErUiSurfaceFrameBudget frame_budget;
  er_ui_resolved_theme_t theme;
  ErUiBootAppContext* apps;
  UINT32 app_count;
  UINT32 active_app;
  er_ui_scene_t* scene;
  ErNativeBootState* native_relay;
  ErUiBootNativeRelayStats native_relay_stats;
  ErRelayTransitHop native_relay_last_transit;
  ErRenderEndpointCapture native_relay_last_render_capture;
  ErRenderEndpointScene native_relay_last_render_scene;
  ErStorageEndpointObjectCapture native_relay_last_storage_capture;
} ErUiBootRenderContext;

extern ErWasmHostCalls g_host_calls;

void* er_ui_boot_alloc(void* user, size_t size, size_t align);
void er_ui_boot_free(void* user, void* ptr, size_t size, size_t align);
void* er_ui_boot_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align);
void er_ui_boot_allocator_reset(void);
er_ui_allocator_t er_ui_boot_allocator(void);
void er_fill_nonzero_bytes(UINT8* bytes, UINTN len, UINT8 seed);
vr_font_allocator_t er_ui_boot_font_allocator(void);
UINT8 er_ui_boot_create_font(UINT32 height, vr_font_face_t** out_font);

void er_print_u64_field(const char* label, UINT64 value);
void er_acpi_signature_name(UINT32 signature, char out_name[ER_ACPI_SIGNATURE_BYTES + 1u]);
void er_log_acpi(EFI_SYSTEM_TABLE* SystemTable);
void er_select_large_console(EFI_SYSTEM_TABLE* SystemTable);
void er_log_u64(INT64 value);
void er_log_hex(UINT64 value);
void er_cpu_idle_once(void);
void er_pause_once(void);
void er_idle_forever(void);
UINT8 er_exit_boot_services(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable);
INT64 er_wasm_bus_exec_host(const ErBusIoPacket* request, ErBusIoPacket* response);
void er_install_hostcalls(void);

UINT8 er_virtio_gpu_wait_ok(ErVirtioGpu* gpu);
UINT8 er_virtio_gpu_wait_display_info(ErVirtioGpu* gpu, ErVirtioGpuDisplayInfo* out_info);
UINT8 er_ui_boot_gpu_present(const ErUiBootRenderContext* render);
UINT8 er_ui_boot_gpu_prepare_scanout(ErVirtioGpu* gpu,
                                     ErVirtioGpuFramebuffer* framebuffer,
                                     ErUiSurface* surface,
                                     ErUiSurfaceMode* out_mode);

UINT8 er_ui_boot_append_wasm_scene(er_ui_scene_t* scene, const er_ui_scene_t* wasm_scene);
UINT8 er_ui_boot_app_seed(UINT8 seed, UINT32 app_index);
void er_ui_boot_prepare_wasm_presentation(const er_ui_scene_budget_t* scene_budget,
                                          UINT32 app_index,
                                          ErAppUiPresentation* out_presentation);
UINT8 er_ui_boot_prepare_storage_retrieve_route(UINT8 route_seed, UINT32 app_index, ErAdmittedRoute* out_route);
UINT8 er_ui_boot_prepare_route_envelope(const ErAdmittedRoute* route,
                                        const ErHash* packet_hash,
                                        UINT64 sequence,
                                        ErChannelEnvelopeHeader* out_envelope);
UINT8 er_ui_boot_execute_wasm_app(ErUiWasmAppRuntime* runtime);
const ErUiBootInstalledApp* er_ui_boot_installed_app_for_slot(UINT32 app_index);
UINT8 er_ui_boot_load_installed_app_package(const ErUiBootInstalledApp* installed_app,
                                            UINT8* module_memory,
                                            UINT32 module_memory_size,
                                            UINT8* manifest_memory,
                                            UINT32 manifest_memory_size,
                                            ErUiBootPackageStorage* storage,
                                            UINT32 app_index,
                                            ErAppLoadedPackage* out_loaded);
UINT8 er_ui_boot_load_user_app_package(UINT8* module_memory,
                                       UINT32 module_memory_size,
                                       UINT8* manifest_memory,
                                       UINT32 manifest_memory_size,
                                       ErUiBootPackageStorage* storage,
                                       UINT32 app_index,
                                       ErAppLoadedPackage* out_loaded);
UINT8 er_ui_boot_prepare_user_app(ErUiWasmAppRuntime* runtime,
                                  ErUiBootPackageStorage* storage,
                                  ErAppUiPresentation* presentation,
                                  er_ui_scene_t* wasm_scene,
                                  UINT8* memory,
                                  UINT32 memory_size,
                                  UINT8* module_memory,
                                  UINT32 module_memory_size,
                                  UINT8* manifest_memory,
                                  UINT32 manifest_memory_size,
                                  UINT32 app_index,
                                  const er_ui_scene_budget_t* scene_budget);
void er_ui_boot_destroy_app_contexts(ErUiBootAppContext* apps, UINT32 app_count);
UINT8 er_ui_boot_prepare_app_contexts(ErUiBootAppContext* apps,
                                      UINT32 app_count,
                                      const er_ui_scene_budget_t* scene_budget,
                                      er_ui_color4_t clear);

ErUiBootAppContext* er_ui_boot_active_app(ErUiBootRenderContext* render);
const ErUiBootAppContext* er_ui_boot_active_app_const(const ErUiBootRenderContext* render);
UINT8 er_ui_boot_switch_app_for_surface(ErUiBootRenderContext* render, UINT32 surface_id);
UINT8 er_ui_boot_render_scene(er_ui_scene_t* scene,
                              er_ui_ledger_app_state_t* ledger_state,
                              const ErUiBootRenderContext* render);
er_ui_action_t er_ui_boot_action_from_ps2(er_ui_runtime_state_t* runtime,
                                          const er_ui_scene_t* scene,
                                          ErPs2KeyboardAction input);
UINT8 er_ui_boot_apply_input(er_ui_ledger_app_state_t* ledger_state,
                             er_ui_runtime_state_t* runtime,
                             er_ui_scene_t* scene,
                             ErUiBootRenderContext* render,
                             ErPs2KeyboardAction input,
                             UINT8* out_redraw);
UINT8 er_ui_boot_dispatch_native_relay_ingress(ErUiBootRenderContext* render,
                                               const ErNativeRelayIngress* ingress,
                                               UINT8* out_redraw);
UINT8 er_ui_boot_poll_native_relay(ErUiBootRenderContext* render,
                                   UINT8* out_redraw);
void er_ui_boot_input_loop(er_ui_ledger_app_state_t* ledger_state,
                           er_ui_runtime_state_t* runtime,
                           er_ui_scene_t* scene,
                           ErUiBootRenderContext* render);

void er_run_os_path(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable,
                    const ErBootServicesReport* boot_report);
void er_run_invalid_boot_path(void);
void er_run_boot_path(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable,
                      const ErBootServicesReport* boot_report);

#endif
