; EdgeRun Virtio GPU protocol constants
; Included by virtio_gpu.asm and consumers.

; ─── Control types (32-bit command IDs) ────────────────────────────
%define VIRTIO_GPU_CMD_GET_DISPLAY_INFO      0x0100
%define VIRTIO_GPU_CMD_RESOURCE_CREATE_2D    0x0101
%define VIRTIO_GPU_CMD_RESOURCE_UNREF        0x0102
%define VIRTIO_GPU_CMD_SET_SCANOUT           0x0103
%define VIRTIO_GPU_CMD_RESOURCE_FLUSH        0x0104
%define VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D   0x0105
%define VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING 0x0106
%define VIRTIO_GPU_CMD_RESOURCE_DETACH_BACKING 0x0107
%define VIRTIO_GPU_CMD_GET_CAPSET_INFO       0x0108
%define VIRTIO_GPU_CMD_GET_CAPSET            0x0109
%define VIRTIO_GPU_CMD_GET_EDID              0x010A

%define VIRTIO_GPU_CMD_CTX_CREATE            0x0200
%define VIRTIO_GPU_CMD_CTX_DESTROY           0x0201
%define VIRTIO_GPU_CMD_CTX_ATTACH_RESOURCE   0x0202
%define VIRTIO_GPU_CMD_CTX_DETACH_RESOURCE   0x0203
%define VIRTIO_GPU_CMD_RESOURCE_CREATE_3D    0x0204
%define VIRTIO_GPU_CMD_TRANSFER_TO_HOST_3D   0x0205
%define VIRTIO_GPU_CMD_TRANSFER_FROM_HOST_3D 0x0206
%define VIRTIO_GPU_CMD_SUBMIT_3D             0x0207

; Response types
%define VIRTIO_GPU_RESP_OK_NODATA            0x1100
%define VIRTIO_GPU_RESP_OK_DISPLAY_INFO      0x1101
%define VIRTIO_GPU_RESP_OK_CAPSET_INFO       0x1102
%define VIRTIO_GPU_RESP_OK_CAPSET            0x1103
%define VIRTIO_GPU_RESP_OK_EDID              0x1104

%define VIRTIO_GPU_RESP_ERR_UNSPEC           0x1200
%define VIRTIO_GPU_RESP_ERR_OUT_OF_MEMORY    0x1201
%define VIRTIO_GPU_RESP_ERR_INVALID_SCANOUT  0x1202
%define VIRTIO_GPU_RESP_ERR_INVALID_RESOURCE 0x1203
%define VIRTIO_GPU_RESP_ERR_INVALID_CONTEXT  0x1204
%define VIRTIO_GPU_RESP_ERR_INVALID_PARAM    0x1205

; ─── Pixel formats ─────────────────────────────────────────────────
%define VIRTIO_GPU_FORMAT_B8G8R8A8_UNORM     1
%define VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM     2
%define VIRTIO_GPU_FORMAT_A8R8G8B8_UNORM     3
%define VIRTIO_GPU_FORMAT_X8R8G8B8_UNORM     4

; ─── 3D resource constants ─────────────────────────────────────────
%define VIRTIO_GPU_RESOURCE_TARGET_TEXTURE_2D 2
%define VIRTIO_GPU_RESOURCE_BIND_RENDER_TARGET (1 << 1)
%define VIRTIO_GPU_RESOURCE_BIND_SAMPLER_VIEW (1 << 3)
%define VIRTIO_GPU_RESOURCE_FLAG_Y_0_TOP      (1 << 0)

; ─── VirGL constants ───────────────────────────────────────────────
%define VIRTIO_GPU_CAPSET_VIRGL               1
%define VIRTIO_GPU_CAPSET_VIRGL2              2

%define VIRTIO_GPU_PIPE_CLEAR_COLOR0          (1 << 2)

; VirGL command opcodes
%define VIRGL_CMD_NOP                         0
%define VIRGL_CMD_CREATE_OBJECT               1
%define VIRGL_CMD_BIND_OBJECT                 2
%define VIRGL_CMD_DESTROY_OBJECT              3
%define VIRGL_CMD_SET_VIEWPORT_STATE          4
%define VIRGL_CMD_SET_FRAMEBUFFER_STATE       5
%define VIRGL_CMD_SET_VERTEX_BUFFERS          6
%define VIRGL_CMD_CLEAR                       7
%define VIRGL_CMD_DRAW_VBO                    8

; VirGL object types
%define VIRGL_OBJ_NULL                        0
%define VIRGL_OBJ_BLEND                       1
%define VIRGL_OBJ_RASTERIZER                  2
%define VIRGL_OBJ_DSA                         3
%define VIRGL_OBJ_SHADER                      4
%define VIRGL_OBJ_VERTEX_ELEMENTS             5
%define VIRGL_OBJ_SAMPLER_VIEW                6
%define VIRGL_OBJ_SAMPLER_STATE               7
%define VIRGL_OBJ_SURFACE                     8
%define VIRGL_OBJ_QUERY                       9
%define VIRGL_OBJ_STREAMOUT_TARGET            10

; ─── Struct sizes (from virtio spec / extern C layout) ─────────────
%define VIRTIO_GPU_HEADER_SIZE                24
%define VIRTIO_GPU_RECT_SIZE                  16
%define VIRTIO_GPU_DISPLAY_SIZE               20
%define VIRTIO_GPU_MEM_ENTRY_SIZE             16
%define VIRTIO_GPU_RESPONSE_SIZE              24

%define VIRTIO_GPU_RESOURCE_CREATE_2D_SIZE    40
%define VIRTIO_GPU_RESOURCE_ATTACH_BACKING_SIZE 48
%define VIRTIO_GPU_SET_SCANOUT_SIZE           48
%define VIRTIO_GPU_TRANSFER_TO_HOST_2D_SIZE   56
%define VIRTIO_GPU_RESOURCE_FLUSH_SIZE        48
%define VIRTIO_GPU_RESOURCE_CREATE_3D_SIZE    72
%define VIRTIO_GPU_CTX_CREATE_SIZE            96
%define VIRTIO_GPU_CTX_DESTROY_SIZE           24
%define VIRTIO_GPU_CTX_RESOURCE_SIZE          32
%define VIRTIO_GPU_SUBMIT_3D_SIZE             32
%define VIRTIO_GPU_GET_CAPSET_INFO_SIZE       32
%define VIRTIO_GPU_CAPSET_INFO_RESP_SIZE      40

; ─── Struct offset helpers (Header fields) ─────────────────────────
; Header: control_type(4) + flags(4) + fence_id(8) + context_id(4) + padding(4)
%define VIRTIO_GPU_HDR_CTRL_TYPE               0
%define VIRTIO_GPU_HDR_FLAGS                   4
%define VIRTIO_GPU_HDR_FENCE_ID                8
%define VIRTIO_GPU_HDR_CONTEXT_ID             16
; header ends at 20+4=24

; ResourceCreate2d: Header(24) + resource_id(4) + format(4) + width(4) + height(4)
%define VIRTIO_GPU_RES2D_RESOURCE_ID          24
%define VIRTIO_GPU_RES2D_FORMAT               28
%define VIRTIO_GPU_RES2D_WIDTH                32
%define VIRTIO_GPU_RES2D_HEIGHT               36

; ResourceAttachBacking: Header(24) + resource_id(4) + nr_entries(4) + MemEntry(16)
%define VIRTIO_GPU_ATTACH_RESOURCE_ID         24
%define VIRTIO_GPU_ATTACH_NR_ENTRIES          28
%define VIRTIO_GPU_ATTACH_ENTRY_ADDR          32  ; MemEntry.address(8) + length(4) + padding(4)
%define VIRTIO_GPU_ATTACH_ENTRY_LEN           40

; SetScanout: Header(24) + rect(16) + scanout_id(4) + resource_id(4)
%define VIRTIO_GPU_SCANOUT_RECT_X             24
%define VIRTIO_GPU_SCANOUT_RECT_Y             28
%define VIRTIO_GPU_SCANOUT_RECT_W             32
%define VIRTIO_GPU_SCANOUT_RECT_H             36
%define VIRTIO_GPU_SCANOUT_SCANOUT_ID         40
%define VIRTIO_GPU_SCANOUT_RESOURCE_ID        44

; TransferToHost2d: Header(24) + rect(16) + offset(8) + resource_id(4) + padding(4)
%define VIRTIO_GPU_T2D_RECT_X                 24
%define VIRTIO_GPU_T2D_RECT_Y                 28
%define VIRTIO_GPU_T2D_RECT_W                 32
%define VIRTIO_GPU_T2D_RECT_H                 36
%define VIRTIO_GPU_T2D_OFFSET                 40
%define VIRTIO_GPU_T2D_RESOURCE_ID            48

; ResourceFlush: Header(24) + rect(16) + resource_id(4) + padding(4)
%define VIRTIO_GPU_FLUSH_RECT_X               24
%define VIRTIO_GPU_FLUSH_RECT_Y               28
%define VIRTIO_GPU_FLUSH_RECT_W               32
%define VIRTIO_GPU_FLUSH_RECT_H               36
%define VIRTIO_GPU_FLUSH_RESOURCE_ID          40
