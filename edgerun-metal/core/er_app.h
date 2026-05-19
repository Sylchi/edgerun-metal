#ifndef ER_APP_H
#define ER_APP_H

/*
 * Purpose: define app identity and IPC routing records for WASM objects.
 * Intention: bind execution to content-addressed app objects without host or locality authority.
 */

#include "er_crypto.h"
#include "er_vfs.h"
#include "er_work.h"
#include "er_ui_scene.h"

#define ER_APP_ABI_VERSION 1u
#define ER_APP_INSTANCE_NONCE_LEN 32u

#define ER_APP_SEAL_POLICY_REQUIRED 1u
#define ER_APP_KIND_UI_APP 1u
#define ER_APP_KIND_BUS_DRIVER 2u
#define ER_APP_KIND_USER ER_APP_KIND_UI_APP
#define ER_APP_ADDRESS_BASE 0u

#define ER_APP_BUDGET_CPU_STEP 0x00000001u
#define ER_APP_BUDGET_MEMORY_BYTE 0x00000002u
#define ER_APP_BUDGET_PACKET_BYTE 0x00000004u
#define ER_APP_BUDGET_STORAGE_BYTE 0x00000008u
#define ER_APP_BUDGET_IPC_SEND 0x00000010u
#define ER_APP_BUDGET_IPC_RECV 0x00000020u

#define ER_APP_PACKAGE_INSTALL_STATE_INSTALLED 1u
#define ER_APP_PACKAGE_INSTALL_STATE_REMOVED 2u
#define ER_APP_PACKAGE_INSTALL_STATE_ROLLED_BACK 3u

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErHash package_id;
  ErHash app_object_id;
  UINT64 app_object_len;
  ErHash manifest_object_id;
  UINT64 manifest_object_len;
  ErHash ui_assets_object_id;
  UINT64 ui_assets_object_len;
} ErAppPackageManifest;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErHash package_id;
  ErIdentity signer;
  ErWorkSignature signature;
} ErAppPackageSignature;

typedef struct {
  const ErVfsObjectPacket* packets;
  UINT32 packet_count;
  UINT8* bytes;
  UINTN capacity;
} ErAppPackageObjectLoad;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErHash package_id;
  UINT8* app_bytes;
  UINTN app_len;
  UINT8* manifest_bytes;
  UINTN manifest_len;
  UINT8* ui_assets_bytes;
  UINTN ui_assets_len;
} ErAppLoadedPackage;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErHash source_id;
  ErHash package_id;
  ErHash app_retrieve_route_id;
  ErHash manifest_retrieve_route_id;
  ErHash ui_assets_retrieve_route_id;
} ErAppPackageStorageSource;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  UINT32 installed_slot;
  ErAppPackageManifest package;
  ErVfsObjectRef app_ref;
  ErVfsObjectRef manifest_ref;
  ErVfsObjectRef ui_assets_ref;
  ErAppPackageStorageSource storage_source;
} ErAppPackageIndexEntry;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErAppPackageIndexEntry index_entry;
  ErAppPackageSignature package_signature;
} ErAppSignedPackageIndexEntry;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  UINT32 install_state;
  UINT32 installed_slot;
  UINT64 generation;
  ErAppSignedPackageIndexEntry current_entry;
  ErAppSignedPackageIndexEntry previous_entry;
} ErAppPackageInstallRecord;

typedef struct {
  ErHash retrieve_route_id;
  ErAppPackageObjectLoad object;
} ErAppPackageStorageObject;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash retrieve_route_id;
  ErHash object_id;
  UINT64 object_len;
  const ErVfsObjectPacket* packets;
  UINT32 packet_count;
  UINT8* bytes;
  UINTN capacity;
} ErAppPackageStorageResponse;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash app_object_id;
  ErHash manifest_hash;
  ErHash admission_id;
  UINT8 instance_nonce[ER_APP_INSTANCE_NONCE_LEN];
  ErNodeId app_node_id;
} ErAppIdentity;

typedef struct {
  UINT16 abi_version;
  UINT16 seal_policy;
  ErHash route_binding_id;
  ErHash session_id;
  ErHash admission_id;
  ErNodeId source_app_node_id;
  ErNodeId target_node_id;
  ErHash capability_id;
  ErHash route_hash;
  UINT64 sequence_base;
  UINT32 capability_risk_flags;
  UINT32 reserved;
} ErAppIpcRouteBinding;

typedef struct {
  UINT16 abi_version;
  UINT16 app_kind;
  ErHash budget_id;
  ErHash admission_id;
  ErHash app_object_id;
  UINT64 max_cpu_steps;
  UINT64 max_memory_bytes;
  UINT64 max_packet_bytes;
  UINT64 max_storage_bytes;
  UINT64 max_ipc_sends;
  UINT64 max_ipc_recvs;
} ErAppBudget;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash budget_id;
  ErNodeId app_node_id;
  UINT64 cpu_steps;
  UINT64 memory_bytes;
  UINT64 packet_bytes;
  UINT64 storage_bytes;
  UINT64 ipc_sends;
  UINT64 ipc_recvs;
} ErAppUsage;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash slot_id;
  ErHash admission_id;
  ErNodeId app_node_id;
  UINT64 deterministic_tick;
  UINT64 sequence;
  UINT64 cpu_step_quanta;
  UINT64 memory_byte_limit;
} ErAppScheduleSlot;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash allocation_id;
  ErHash admission_id;
  ErHash budget_id;
  ErNodeId app_node_id;
  UINT64 executor_memory_base;
  UINT64 executor_memory_len;
  UINT64 app_address_base;
  UINT64 app_address_len;
} ErAppLaunchAllocation;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash jurisdiction_id;
  ErHash admission_id;
  ErHash budget_id;
  ErHash allocation_id;
  ErNodeId parent_relay_node_id;
  ErNodeId app_node_id;
  UINT64 app_address_base;
  UINT64 app_address_len;
  UINT64 public_inbox_base;
  UINT64 public_inbox_len;
  UINT64 public_outbox_base;
  UINT64 public_outbox_len;
} ErAppExecutionJurisdiction;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash presentation_id;
  ErHash jurisdiction_id;
  ErHash admission_id;
  ErNodeId app_node_id;
  ErNodeId ui_relay_node_id;
  ErHash route_hash;
  UINT64 sequence;
  UINT64 max_rects;
  UINT64 max_hits;
  UINT64 max_drag_sources;
  UINT64 max_drop_targets;
  UINT64 max_transitions;
  UINT64 max_icon_quads;
  UINT64 max_text_quads;
} ErAppUiPresentation;

UINT8 er_app_derive_identity(const ErCryptoProvider* crypto, const ErHash* app_object_id,
                             const ErHash* manifest_hash, const ErHash* admission_id,
                             const UINT8* instance_nonce, UINTN instance_nonce_len,
                             ErAppIdentity* out_identity);
UINT8 er_app_prepare_package_manifest(const ErCryptoProvider* crypto,
                                      const ErVfsObjectLabelRef* app_object,
                                      const ErVfsObjectLabelRef* manifest_object,
                                      const ErVfsObjectLabelRef* ui_assets_object,
                                      ErAppPackageManifest* out_package);
UINT8 er_app_prepare_package_manifest_for_kind(const ErCryptoProvider* crypto,
                                               UINT16 app_kind,
                                               const ErVfsObjectLabelRef* app_object,
                                               const ErVfsObjectLabelRef* manifest_object,
                                               const ErVfsObjectLabelRef* ui_assets_object,
                                               ErAppPackageManifest* out_package);
UINT8 er_app_prepare_package_manifest_from_objects(const ErCryptoProvider* crypto,
                                                   const ErVfsObjectRef* app_object,
                                                   const ErVfsObjectRef* manifest_object,
                                                   const ErVfsObjectRef* ui_assets_object,
                                                   ErAppPackageManifest* out_package);
UINT8 er_app_prepare_package_manifest_from_objects_for_kind(const ErCryptoProvider* crypto,
                                                            UINT16 app_kind,
                                                            const ErVfsObjectRef* app_object,
                                                            const ErVfsObjectRef* manifest_object,
                                                            const ErVfsObjectRef* ui_assets_object,
                                                            ErAppPackageManifest* out_package);
UINT8 er_app_sign_package(const ErCryptoProvider* crypto,
                          const ErAppPackageManifest* package,
                          const ErIdentity* signer,
                          ErAppPackageSignature* out_signature);
UINT8 er_app_verify_package_signature(const ErCryptoProvider* crypto,
                                      const ErAppPackageManifest* package,
                                      const ErAppPackageSignature* signature);
UINT8 er_app_load_package_objects(const ErCryptoProvider* crypto,
                                  const ErAppPackageManifest* package,
                                  const ErAppPackageObjectLoad* app_object,
                                  const ErAppPackageObjectLoad* manifest_object,
                                  const ErAppPackageObjectLoad* ui_assets_object,
                                  ErAppLoadedPackage* out_loaded);
UINT8 er_app_prepare_package_storage_source(const ErCryptoProvider* crypto,
                                            const ErAppPackageManifest* package,
                                            const ErAdmittedRoute* app_route,
                                            const ErAdmittedRoute* manifest_route,
                                            const ErAdmittedRoute* ui_assets_route,
                                            ErAppPackageStorageSource* out_source);
UINT8 er_app_prepare_package_index_entry(const ErCryptoProvider* crypto,
                                         const ErAppPackageManifest* package,
                                         const ErVfsObjectRef* app_ref,
                                         const ErVfsObjectRef* manifest_ref,
                                         const ErVfsObjectRef* ui_assets_ref,
                                         const ErAppPackageStorageSource* storage_source,
                                         UINT32 installed_slot,
                                         ErAppPackageIndexEntry* out_entry);
UINT8 er_app_package_index_entry_valid(const ErCryptoProvider* crypto,
                                       const ErAppPackageIndexEntry* entry);
UINT8 er_app_prepare_signed_package_index_entry(const ErCryptoProvider* crypto,
                                                const ErAppPackageIndexEntry* entry,
                                                const ErAppPackageSignature* signature,
                                                ErAppSignedPackageIndexEntry* out_entry);
UINT8 er_app_signed_package_index_entry_valid(const ErCryptoProvider* crypto,
                                              const ErAppSignedPackageIndexEntry* entry);
UINT8 er_app_package_install_record_valid(const ErCryptoProvider* crypto,
                                          const ErAppPackageInstallRecord* record);
UINT8 er_app_prepare_package_install_record(const ErCryptoProvider* crypto,
                                            UINT32 install_state,
                                            UINT64 generation,
                                            const ErAppSignedPackageIndexEntry* current_entry,
                                            const ErAppSignedPackageIndexEntry* previous_entry,
                                            ErAppPackageInstallRecord* out_record);
UINT8 er_app_package_install_record_loadable(const ErCryptoProvider* crypto,
                                             const ErAppPackageInstallRecord* record);
UINT8 er_app_prepare_package_storage_object(const ErAppPackageStorageResponse* response,
                                            const ErHash* expected_route_id,
                                            const ErHash* expected_object_id,
                                            UINT64 expected_object_len,
                                            ErAppPackageStorageObject* out_object);
UINT8 er_app_load_package_from_storage_source(const ErCryptoProvider* crypto,
                                              const ErAppPackageManifest* package,
                                              const ErAppPackageStorageSource* source,
                                              const ErAppPackageStorageObject* app_object,
                                              const ErAppPackageStorageObject* manifest_object,
                                              const ErAppPackageStorageObject* ui_assets_object,
                                              ErAppLoadedPackage* out_loaded);
UINT8 er_app_derive_identity_from_package(const ErCryptoProvider* crypto,
                                          const ErAppPackageManifest* package,
                                          const ErHash* admission_id,
                                          const UINT8* instance_nonce,
                                          UINTN instance_nonce_len,
                                          ErAppIdentity* out_identity);
UINT8 er_app_prepare_ipc_route_binding(const ErCryptoProvider* crypto, const ErAppIdentity* source_app,
                                       const ErNodeId* target_node_id, const ErHash* capability_id,
                                       const ErHash* route_hash, UINT64 sequence_base,
                                       UINT32 capability_risk_flags, ErAppIpcRouteBinding* out_binding);
UINT8 er_app_prepare_budget(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                            UINT16 app_kind, UINT64 max_cpu_steps, UINT64 max_memory_bytes,
                            UINT64 max_packet_bytes, UINT64 max_storage_bytes,
                            UINT64 max_ipc_sends, UINT64 max_ipc_recvs,
                            ErAppBudget* out_budget);
UINT8 er_app_usage_init(const ErAppIdentity* identity, const ErAppBudget* budget, ErAppUsage* out_usage);
UINT8 er_app_usage_charge(ErAppUsage* usage, const ErAppBudget* budget, UINT32 resource_kind, UINT64 amount);
UINT8 er_app_prepare_schedule_slot(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                   const ErAppBudget* budget, UINT64 deterministic_tick,
                                   UINT64 sequence, ErAppScheduleSlot* out_slot);
UINT8 er_app_prepare_launch_allocation(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                       const ErAppBudget* budget, UINT64 executor_memory_base,
                                       UINT64 executor_memory_len, ErAppLaunchAllocation* out_allocation);
UINT8 er_app_prepare_execution_jurisdiction(const ErCryptoProvider* crypto,
                                            const ErAppIdentity* identity,
                                            const ErAppBudget* budget,
                                            const ErAppLaunchAllocation* allocation,
                                            const ErNodeId* parent_relay_node_id,
                                            UINT64 public_inbox_base,
                                            UINT64 public_inbox_len,
                                            UINT64 public_outbox_base,
                                            UINT64 public_outbox_len,
                                            ErAppExecutionJurisdiction* out_jurisdiction);
UINT8 er_app_prepare_ui_presentation(const ErCryptoProvider* crypto,
                                     const ErAppExecutionJurisdiction* jurisdiction,
                                     const ErNodeId* ui_relay_node_id,
                                     const ErHash* route_hash,
                                     er_ui_scene_budget_t scene_budget,
                                     UINT64 sequence,
                                     ErAppUiPresentation* out_presentation);
UINT8 er_app_ui_scene_fits_presentation(er_ui_scene_stats_t stats,
                                        const ErAppUiPresentation* presentation);

#endif
