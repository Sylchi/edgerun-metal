; JC3248W535 ESP32-S3 board and BLE UI contract descriptor.

%include "esp32s3/jc3248w535/registers.inc"

%define JC_MAGIC_0              'E'
%define JC_MAGIC_1              'R'
%define JC_MAGIC_2              'J'
%define JC_MAGIC_3              'C'
%define JC_VERSION              1

%define JC_LCD_CONTROLLER       0x15231b

firmware_descriptor:
    db JC_MAGIC_0, JC_MAGIC_1, JC_MAGIC_2, JC_MAGIC_3
    dd JC_VERSION
    dd JC3248_LCD_WIDTH
    dd JC3248_LCD_HEIGHT
    dd JC3248_LCD_RGB565_BPP
    dd JC_LCD_CONTROLLER
    dd JC3248_TOUCH_I2C_ADDR
    dd JC3248_PIN_BL
    dd JC3248_PIN_TOUCH_SDA
    dd JC3248_PIN_LCD_DC_TOUCH_SCL
    dd JC3248_PIN_LCD_D0
    dd JC3248_PIN_LCD_TE
    dd JC3248_PIN_LCD_D3
    dd JC3248_PIN_LCD_D2
    dd JC3248_PIN_LCD_CS
    dd JC3248_PIN_LCD_CLK
    dd JC3248_PIN_LCD_D1
    dd ESP32S3_SPI2_BASE
    dd ESP32S3_GPIO_BASE
    dd ESP32S3_I2C0_BASE
    dd ESP32S3_USB_SERIAL_JTAG
    dd JC3248_BLE_FRAME_MAGIC
    dd JC3248_BLE_FRAME_VERSION
    dd JC3248_BLE_FRAME_HEADER
    dd JC3248_BLE_LEGACY_PAYLOAD
    dd JC3248_BLE_ROUTE_DISPLAY
    dd JC3248_BLE_ROUTE_CONTROL
    db "jc3248w535 esp32-s3 ble display control", 0
firmware_descriptor_end:

times 256 - ($ - $$) db 0
