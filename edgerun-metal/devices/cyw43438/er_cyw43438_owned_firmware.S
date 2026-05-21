.syntax unified
.thumb

.equ ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR, 0x00000009
.equ ER_CYW43438_OWNED_FIRMWARE_SHARED_BASE, 0x00000400
.equ ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC, 0x45524359
.equ ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK, 0x80000000
.equ ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR, 0x00000500
.equ ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR, 0x00000580

.section .text, "ax"
.word ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR
.word 0

.thumb_func
er_cyw43438_owned_firmware_entry:
  ldr r0, er_cyw43438_owned_firmware_shared_base
  ldr r1, er_cyw43438_owned_firmware_mailbox_magic
  ldr r4, er_cyw43438_owned_firmware_ack_mask
  str r1, [r0]
  movs r2, #0
  adds r2, #1
  str r2, [r0, #4]

er_cyw43438_owned_firmware_loop:
  ldr r3, [r0, #8]
  cmp r3, #0
  beq er_cyw43438_owned_firmware_loop

  ldr r6, er_cyw43438_owned_firmware_tx_frame
  str r6, [r0, #32]
  ldr r5, [r0, #16]
  str r5, [r0, #36]
  ldrb r7, [r6]
  lsls r5, r5, #8
  orrs r5, r7
  str r5, [r0, #20]
  str r5, [r0, #40]

  ldr r6, er_cyw43438_owned_firmware_rx_frame
  ldr r5, [r0, #24]
  ldrb r7, [r6]
  lsls r5, r5, #8
  orrs r5, r7
  str r5, [r0, #28]

  orrs r3, r4
  str r3, [r0, #12]
  b er_cyw43438_owned_firmware_loop

.align 2
er_cyw43438_owned_firmware_shared_base:
  .word ER_CYW43438_OWNED_FIRMWARE_SHARED_BASE
er_cyw43438_owned_firmware_mailbox_magic:
  .word ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC
er_cyw43438_owned_firmware_ack_mask:
  .word ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ACK_MASK
er_cyw43438_owned_firmware_tx_frame:
  .word ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR
er_cyw43438_owned_firmware_rx_frame:
  .word ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR
