# 🧩 Altera DE0 FPGA Board – Complete Component-to-Pin Mapping

This document lists all component connections between the **Cyclone III 3C16 FPGA** and onboard peripherals of the **Terasic DE0 Development Board**, as extracted from the official DE0 User Manual (2012).

---

## 1. Slide Switches
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| SW[0] | PIN_J6 | Slide Switch[0] |
| SW[1] | PIN_H5 | Slide Switch[1] |
| SW[2] | PIN_H6 | Slide Switch[2] |
| SW[3] | PIN_G4 | Slide Switch[3] |
| SW[4] | PIN_G5 | Slide Switch[4] |
| SW[5] | PIN_J7 | Slide Switch[5] |
| SW[6] | PIN_H7 | Slide Switch[6] |
| SW[7] | PIN_E3 | Slide Switch[7] |
| SW[8] | PIN_E4 | Slide Switch[8] |
| SW[9] | PIN_D2 | Slide Switch[9] |

---

## 2. Push Buttons
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| BUTTON[0] | PIN_H2 | Pushbutton[0] |
| BUTTON[1] | PIN_G3 | Pushbutton[1] |
| BUTTON[2] | PIN_F1 | Pushbutton[2] |

---

## 3. LEDs
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| LEDG[0] | PIN_J1 | LED Green[0] |
| LEDG[1] | PIN_J2 | LED Green[1] |
| LEDG[2] | PIN_J3 | LED Green[2] |
| LEDG[3] | PIN_H1 | LED Green[3] |
| LEDG[4] | PIN_F2 | LED Green[4] |
| LEDG[5] | PIN_E1 | LED Green[5] |
| LEDG[6] | PIN_C1 | LED Green[6] |
| LEDG[7] | PIN_C2 | LED Green[7] |
| LEDG[8] | PIN_B2 | LED Green[8] |
| LEDG[9] | PIN_B1 | LED Green[9] |

---

## 4. 7-Segment Displays
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| HEX0_D[0] | PIN_E11 | Digit 0[0] |
| HEX0_D[1] | PIN_F11 | Digit 0[1] |
| HEX0_D[2] | PIN_H12 | Digit 0[2] |
| HEX0_D[3] | PIN_H13 | Digit 0[3] |
| HEX0_D[4] | PIN_G12 | Digit 0[4] |
| HEX0_D[5] | PIN_F12 | Digit 0[5] |
| HEX0_D[6] | PIN_F13 | Digit 0[6] |
| HEX0_DP | PIN_D13 | Decimal Point 0 |
| HEX1_D[0] | PIN_A13 | Digit 1[0] |
| HEX1_D[1] | PIN_B13 | Digit 1[1] |
| HEX1_D[2] | PIN_C13 | Digit 1[2] |
| HEX1_D[3] | PIN_A14 | Digit 1[3] |
| HEX1_D[4] | PIN_B14 | Digit 1[4] |
| HEX1_D[5] | PIN_E14 | Digit 1[5] |
| HEX1_D[6] | PIN_A15 | Digit 1[6] |
| HEX1_DP | PIN_B15 | Decimal Point 1 |
| HEX2_D[0] | PIN_D15 | Digit 2[0] |
| HEX2_D[1] | PIN_A16 | Digit 2[1] |
| HEX2_D[2] | PIN_B16 | Digit 2[2] |
| HEX2_D[3] | PIN_E15 | Digit 2[3] |
| HEX2_D[4] | PIN_A17 | Digit 2[4] |
| HEX2_D[5] | PIN_B17 | Digit 2[5] |
| HEX2_D[6] | PIN_F14 | Digit 2[6] |
| HEX2_DP | PIN_A18 | Decimal Point 2 |
| HEX3_D[0] | PIN_B18 | Digit 3[0] |
| HEX3_D[1] | PIN_F15 | Digit 3[1] |
| HEX3_D[2] | PIN_A19 | Digit 3[2] |
| HEX3_D[3] | PIN_B19 | Digit 3[3] |
| HEX3_D[4] | PIN_C19 | Digit 3[4] |
| HEX3_D[5] | PIN_D19 | Digit 3[5] |
| HEX3_D[6] | PIN_G15 | Digit 3[6] |
| HEX3_DP | PIN_G16 | Decimal Point 3 |

---

## 5. Clock Inputs
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| CLOCK_50 | PIN_G21 | 50 MHz Clock |
| CLOCK_50_2 | PIN_B12 | 50 MHz Clock |

---

## 6. LCD Module
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| LCD_DATA[0] | PIN_D22 | Data[0] |
| LCD_DATA[1] | PIN_D21 | Data[1] |
| LCD_DATA[2] | PIN_C22 | Data[2] |
| LCD_DATA[3] | PIN_C21 | Data[3] |
| LCD_DATA[4] | PIN_B22 | Data[4] |
| LCD_DATA[5] | PIN_B21 | Data[5] |
| LCD_DATA[6] | PIN_D20 | Data[6] |
| LCD_DATA[7] | PIN_C20 | Data[7] |
| LCD_RW | PIN_E22 | Read/Write |
| LCD_EN | PIN_E21 | Enable |
| LCD_RS | PIN_F22 | Register Select |
| LCD_BLON | PIN_F21 | Backlight ON/OFF |

---

## 7. VGA
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| VGA_R[0] | PIN_H19 | Red[0] |
| VGA_R[1] | PIN_H17 | Red[1] |
| VGA_R[2] | PIN_H20 | Red[2] |
| VGA_R[3] | PIN_H21 | Red[3] |
| VGA_G[0] | PIN_H22 | Green[0] |
| VGA_G[1] | PIN_J17 | Green[1] |
| VGA_G[2] | PIN_K17 | Green[2] |
| VGA_G[3] | PIN_J21 | Green[3] |
| VGA_B[0] | PIN_K22 | Blue[0] |
| VGA_B[1] | PIN_K21 | Blue[1] |
| VGA_B[2] | PIN_J22 | Blue[2] |
| VGA_B[3] | PIN_K18 | Blue[3] |
| VGA_HS | PIN_L21 | H-Sync |
| VGA_VS | PIN_L22 | V-Sync |

---

## 8. RS-232 Serial
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| UART_RXD | PIN_U22 | UART Receive |
| UART_TXD | PIN_U21 | UART Transmit |
| UART_CTS | PIN_V21 | Clear to Send |
| UART_RTS | PIN_V22 | Request to Send |

---

## 9. PS/2
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| PS2_KBCLK | PIN_P22 | Keyboard Clock |
| PS2_KBDAT | PIN_P21 | Keyboard Data |
| PS2_MSCLK | PIN_R21 | Mouse Clock |
| PS2_MSDAT | PIN_R22 | Mouse Data |

---

## 10. SD Card
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| SD_CLK | PIN_Y21 | SD Clock |
| SD_CMD | PIN_Y22 | Command |
| SD_DAT0 | PIN_AA22 | Data[0] |
| SD_DAT3 | PIN_W21 | Data[3] |
| SD_WP_N | PIN_W20 | Write Protect (active low) |

---

## 11. SDRAM (8 MB)
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| DRAM_ADDR[0] | PIN_C4 | Address[0] |
| DRAM_ADDR[1] | PIN_A3 | Address[1] |
| DRAM_ADDR[2] | PIN_B3 | Address[2] |
| DRAM_ADDR[3] | PIN_C3 | Address[3] |
| DRAM_ADDR[4] | PIN_A5 | Address[4] |
| DRAM_ADDR[5] | PIN_C6 | Address[5] |
| DRAM_ADDR[6] | PIN_B6 | Address[6] |
| DRAM_ADDR[7] | PIN_A6 | Address[7] |
| DRAM_ADDR[8] | PIN_C7 | Address[8] |
| DRAM_ADDR[9] | PIN_B7 | Address[9] |
| DRAM_ADDR[10] | PIN_B4 | Address[10] |
| DRAM_ADDR[11] | PIN_A7 | Address[11] |
| DRAM_ADDR[12] | PIN_C8 | Address[12] |
| DRAM_DQ[0] | PIN_D10 | Data[0] |
| DRAM_DQ[1] | PIN_G10 | Data[1] |
| DRAM_DQ[2] | PIN_H10 | Data[2] |
| DRAM_DQ[3] | PIN_E9 | Data[3] |
| DRAM_DQ[4] | PIN_F9 | Data[4] |
| DRAM_DQ[5] | PIN_G9 | Data[5] |
| DRAM_DQ[6] | PIN_H9 | Data[6] |
| DRAM_DQ[7] | PIN_F8 | Data[7] |
| DRAM_DQ[8] | PIN_A8 | Data[8] |
| DRAM_DQ[9] | PIN_B9 | Data[9] |
| DRAM_DQ[10] | PIN_A9 | Data[10] |
| DRAM_DQ[11] | PIN_C10 | Data[11] |
| DRAM_DQ[12] | PIN_B10 | Data[12] |
| DRAM_DQ[13] | PIN_A10 | Data[13] |
| DRAM_DQ[14] | PIN_E10 | Data[14] |
| DRAM_DQ[15] | PIN_F10 | Data[15] |
| DRAM_BA_0 | PIN_B5 | Bank Address[0] |
| DRAM_BA_1 | PIN_A4 | Bank Address[1] |
| DRAM_LDQM | PIN_E7 | Low-byte Mask |
| DRAM_UDQM | PIN_B8 | High-byte Mask |
| DRAM_RAS_N | PIN_F7 | Row Address Strobe |
| DRAM_CAS_N | PIN_G8 | Column Address Strobe |
| DRAM_CKE | PIN_E6 | Clock Enable |
| DRAM_CLK | PIN_E5 | Clock |
| DRAM_WE_N | PIN_D6 | Write Enable |
| DRAM_CS_N | PIN_G7 | Chip Select |

---

## 12. Flash Memory (4 MB)
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| FL_ADDR[0] | PIN_P7 | Address[0] |
| FL_ADDR[1] | PIN_P5 | Address[1] |
| FL_ADDR[2] | PIN_P6 | Address[2] |
| FL_ADDR[3] | PIN_N7 | Address[3] |
| FL_ADDR[4] | PIN_N5 | Address[4] |
| FL_ADDR[5] | PIN_N6 | Address[5] |
| FL_ADDR[6] | PIN_M8 | Address[6] |
| FL_ADDR[7] | PIN_M4 | Address[7] |
| FL_ADDR[8] | PIN_P2 | Address[8] |
| FL_ADDR[9] | PIN_N2 | Address[9] |
| FL_ADDR[10] | PIN_N1 | Address[10] |
| FL_ADDR[11] | PIN_M3 | Address[11] |
| FL_ADDR[12] | PIN_M2 | Address[12] |
| FL_ADDR[13] | PIN_M1 | Address[13] |
| FL_ADDR[14] | PIN_L7 | Address[14] |
| FL_ADDR[15] | PIN_L6 | Address[15] |
| FL_ADDR[16] | PIN_AA2 | Address[16] |
| FL_ADDR[17] | PIN_M5 | Address[17] |
| FL_ADDR[18] | PIN_M6 | Address[18] |
| FL_ADDR[19] | PIN_P1 | Address[19] |
| FL_ADDR[20] | PIN_P3 | Address[20] |
| FL_ADDR[21] | PIN_R2 | Address[21] |
| FL_DQ[0] | PIN_R7 | Data[0] |
| FL_DQ[1] | PIN_P8 | Data[1] |
| FL_DQ[2] | PIN_R8 | Data[2] |
| FL_DQ[3] | PIN_U1 | Data[3] |
| FL_DQ[4] | PIN_V2 | Data[4] |
| FL_DQ[5] | PIN_V3 | Data[5] |
| FL_DQ[6] | PIN_W1 | Data[6] |
| FL_DQ[7] | PIN_Y1 | Data[7] |
| FL_DQ[8] | PIN_T5 | Data[8] |
| FL_DQ[9] | PIN_T7 | Data[9] |
| FL_DQ[10] | PIN_T4 | Data[10] |
| FL_DQ[11] | PIN_U2 | Data[11] |
| FL_DQ[12] | PIN_V1 | Data[12] |
| FL_DQ[13] | PIN_V4 | Data[13] |
| FL_DQ[14] | PIN_W2 | Data[14] |
| FL_DQ15_AM1 | PIN_Y2 | Data[15] |
| FL_BYTE_N | PIN_AA1 | Byte/Word Mode |
| FL_CE_N | PIN_N8 | Chip Enable |
| FL_OE_N | PIN_R6 | Output Enable |
| FL_RST_N | PIN_R1 | Reset |
| FL_RY | PIN_M7 | Ready/Busy Output |
| FL_WE_N | PIN_P4 | Write Enable |
| FL_WP_N | PIN_T3 | Write Protect |

---

## 13. Expansion Headers (GPIO0 and GPIO1)
| Signal Name | FPGA Pin | Description |
|--------------|-----------|-------------|
| GPIO0_D[0] | PIN_AB16 | IO[0] |
| GPIO0_D[1] | PIN_AA16 | IO[1] |
| GPIO0_D[2] | PIN_AA15 | IO[2] |
| GPIO0_D[3] | PIN_AB15 | IO[3] |
| GPIO0_D[4] | PIN_AA14 | IO[4] |
| GPIO0_D[5] | PIN_AB14 | IO[5] |
| GPIO0_D[6] | PIN_AB13 | IO[6] |
| GPIO0_D[7] | PIN_AA13 | IO[7] |
| GPIO0_D[8] | PIN_AB10 | IO[8] |
| GPIO0_D[9] | PIN_AA10 | IO[9] |
| GPIO0_D[10] | PIN_AB8 | IO[10] |
| GPIO0_D[11] | PIN_AA8 | IO[11] |
| GPIO0_D[12] | PIN_AB5 | IO[12] |
| GPIO0_D[13] | PIN_AA5 | IO[13] |
| GPIO0_D[14] | PIN_AB4 | IO[14] |
| GPIO0_D[15] | PIN_AA4 | IO[15] |
| GPIO0_D[16] | PIN_V14 | IO[16] |
| GPIO0_D[17] | PIN_U14 | IO[17] |
| GPIO0_D[18] | PIN_Y13 | IO[18] |
| GPIO0_D[19] | PIN_W13 | IO[19] |
| GPIO0_D[20] | PIN_U13 | IO[20] |
| GPIO0_D[21] | PIN_V12 | IO[21] |
| GPIO0_D[22] | PIN_R10 | IO[22] |
| GPIO0_D[23] | PIN_V11 | IO[23] |
| GPIO0_D[24] | PIN_Y10 | IO[24] |
| GPIO0_D[25] | PIN_W10 | IO[25] |
| GPIO0_D[26] | PIN_T8 | IO[26] |
| GPIO0_D[27] | PIN_V8 | IO[27] |
| GPIO0_D[28] | PIN_W7 | IO[28] |
| GPIO0_D[29] | PIN_W6 | IO[29] |
| GPIO0_D[30] | PIN_V5 | IO[30] |
| GPIO0_D[31] | PIN_U7 | IO[31] |
| GPIO0_CLKIN[0] | PIN_AB12 | PLL In |
| GPIO0_CLKIN[1] | PIN_AA12 | PLL In |
| GPIO0_CLKOUT[0] | PIN_AB3 | PLL Out |
| GPIO0_CLKOUT[1] | PIN_AA3 | PLL Out |
| GPIO1_D[0] | PIN_AA20 | IO[0] |
| GPIO1_D[1] | PIN_AB20 | IO[1] |
| GPIO1_D[2] | PIN_AA19 | IO[2] |
| GPIO1_D[3] | PIN_AB19 | IO[3] |
| GPIO1_D[4] | PIN_AA18 | IO[4] |
| GPIO1_D[5] | PIN_AB18 | IO[5] |
| GPIO1_D[6] | PIN_AA17 | IO[6] |
| GPIO1_D[7] | PIN_AB17 | IO[7] |
| GPIO1_D[8] | PIN_AA9 | IO[8] |
| GPIO1_D[9] | PIN_AB9 | IO[9] |
| GPIO1_D[10] | PIN_AA7 | IO[10] |
| GPIO1_D[11] | PIN_AB7 | IO[11] |
| GPIO1_D[12] | PIN_AA6 | IO[12] |
| GPIO1_D[13] | PIN_AB6 | IO[13] |
| GPIO1_D[14] | PIN_AA11 | IO[14] |
| GPIO1_D[15] | PIN_AB11 | IO[15] |
| GPIO1_D[16] | PIN_Y16 | IO[16] |
| GPIO1_D[17] | PIN_W16 | IO[17] |
| GPIO1_D[18] | PIN_V16 | IO[18] |
| GPIO1_D[19] | PIN_U16 | IO[19] |
| GPIO1_D[20] | PIN_Y15 | IO[20] |
| GPIO1_D[21] | PIN_W15 | IO[21] |
| GPIO1_D[22] | PIN_V15 | IO[22] |
| GPIO1_D[23] | PIN_U15 | IO[23] |
| GPIO1_D[24] | PIN_T14 | IO[24] |
| GPIO1_D[25] | PIN_R14 | IO[25] |
| GPIO1_D[26] | PIN_Y14 | IO[26] |
| GPIO1_D[27] | PIN_W14 | IO[27] |
| GPIO1_D[28] | PIN_T13 | IO[28] |
| GPIO1_D[29] | PIN_R13 | IO[29] |
| GPIO1_D[30] | PIN_V13 | IO[30] |
| GPIO1_D[31] | PIN_U12 | IO[31] |
| GPIO1_CLKIN[0] | PIN_AB21 | PLL In |
| GPIO1_CLKIN[1] | PIN_AA21 | PLL In |
| GPIO1_CLKOUT[0] | PIN_AB22 | PLL Out |
| GPIO1_CLKOUT[1] | PIN_AA22 | PLL Out |

---
