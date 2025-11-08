-- Copyright (C) 1991-2013 Altera Corporation
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, Altera MegaCore Function License 
-- Agreement, or other applicable license agreement, including, 
-- without limitation, that your use is for the sole purpose of 
-- programming logic devices manufactured by Altera and sold by 
-- Altera or its authorized distributors.  Please refer to the 
-- applicable agreement for further details.

-- VENDOR "Altera"
-- PROGRAM "Quartus II 64-Bit"
-- VERSION "Version 13.1.0 Build 162 10/23/2013 SJ Web Edition"

-- DATE "11/08/2025 08:15:36"

-- 
-- Device: Altera EP3C16F484C6 Package FBGA484
-- 

-- 
-- This VHDL file should be used for ModelSim-Altera (VHDL) only
-- 

LIBRARY ALTERA;
LIBRARY CYCLONEIII;
LIBRARY IEEE;
USE ALTERA.ALTERA_PRIMITIVES_COMPONENTS.ALL;
USE CYCLONEIII.CYCLONEIII_COMPONENTS.ALL;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY 	seven_segment_4digit IS
    PORT (
	clk : IN std_logic;
	reset_n : IN std_logic;
	digits : IN std_logic_vector(15 DOWNTO 0);
	dp_in : IN std_logic_vector(3 DOWNTO 0);
	seg : OUT std_logic_vector(6 DOWNTO 0);
	dp : OUT std_logic;
	dig_en : OUT std_logic_vector(3 DOWNTO 0)
	);
END seven_segment_4digit;

-- Design Ports Information
-- seg[0]	=>  Location: PIN_G11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[1]	=>  Location: PIN_B9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[2]	=>  Location: PIN_C10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[3]	=>  Location: PIN_A7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[4]	=>  Location: PIN_E10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[5]	=>  Location: PIN_A10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[6]	=>  Location: PIN_D10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp	=>  Location: PIN_Y6,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[0]	=>  Location: PIN_G12,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[1]	=>  Location: PIN_A15,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[2]	=>  Location: PIN_F13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[3]	=>  Location: PIN_H12,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[8]	=>  Location: PIN_E12,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[4]	=>  Location: PIN_C13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[0]	=>  Location: PIN_A14,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[12]	=>  Location: PIN_A9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[5]	=>  Location: PIN_B8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[9]	=>  Location: PIN_F11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[1]	=>  Location: PIN_B7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[13]	=>  Location: PIN_B13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[10]	=>  Location: PIN_B10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[6]	=>  Location: PIN_H11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[2]	=>  Location: PIN_A8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[14]	=>  Location: PIN_D13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[11]	=>  Location: PIN_E11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[7]	=>  Location: PIN_B14,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[3]	=>  Location: PIN_E13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[15]	=>  Location: PIN_A13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- clk	=>  Location: PIN_G2,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- reset_n	=>  Location: PIN_G1,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[1]	=>  Location: PIN_H13,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[2]	=>  Location: PIN_B15,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[0]	=>  Location: PIN_B16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[3]	=>  Location: PIN_F12,	 I/O Standard: 2.5 V,	 Current Strength: Default


ARCHITECTURE structure OF seven_segment_4digit IS
SIGNAL gnd : std_logic := '0';
SIGNAL vcc : std_logic := '1';
SIGNAL unknown : std_logic := 'X';
SIGNAL devoe : std_logic := '1';
SIGNAL devclrn : std_logic := '1';
SIGNAL devpor : std_logic := '1';
SIGNAL ww_devoe : std_logic;
SIGNAL ww_devclrn : std_logic;
SIGNAL ww_devpor : std_logic;
SIGNAL ww_clk : std_logic;
SIGNAL ww_reset_n : std_logic;
SIGNAL ww_digits : std_logic_vector(15 DOWNTO 0);
SIGNAL ww_dp_in : std_logic_vector(3 DOWNTO 0);
SIGNAL ww_seg : std_logic_vector(6 DOWNTO 0);
SIGNAL ww_dp : std_logic;
SIGNAL ww_dig_en : std_logic_vector(3 DOWNTO 0);
SIGNAL \clk~inputclkctrl_INCLK_bus\ : std_logic_vector(3 DOWNTO 0);
SIGNAL \reset_n~inputclkctrl_INCLK_bus\ : std_logic_vector(3 DOWNTO 0);
SIGNAL \seg[0]~output_o\ : std_logic;
SIGNAL \seg[1]~output_o\ : std_logic;
SIGNAL \seg[2]~output_o\ : std_logic;
SIGNAL \seg[3]~output_o\ : std_logic;
SIGNAL \seg[4]~output_o\ : std_logic;
SIGNAL \seg[5]~output_o\ : std_logic;
SIGNAL \seg[6]~output_o\ : std_logic;
SIGNAL \dp~output_o\ : std_logic;
SIGNAL \dig_en[0]~output_o\ : std_logic;
SIGNAL \dig_en[1]~output_o\ : std_logic;
SIGNAL \dig_en[2]~output_o\ : std_logic;
SIGNAL \dig_en[3]~output_o\ : std_logic;
SIGNAL \clk~input_o\ : std_logic;
SIGNAL \clk~inputclkctrl_outclk\ : std_logic;
SIGNAL \digits[8]~input_o\ : std_logic;
SIGNAL \refresh_counter[0]~14_combout\ : std_logic;
SIGNAL \reset_n~input_o\ : std_logic;
SIGNAL \reset_n~inputclkctrl_outclk\ : std_logic;
SIGNAL \refresh_counter[3]~21\ : std_logic;
SIGNAL \refresh_counter[4]~22_combout\ : std_logic;
SIGNAL \refresh_counter[4]~23\ : std_logic;
SIGNAL \refresh_counter[5]~24_combout\ : std_logic;
SIGNAL \refresh_counter[5]~25\ : std_logic;
SIGNAL \refresh_counter[6]~26_combout\ : std_logic;
SIGNAL \refresh_counter[6]~27\ : std_logic;
SIGNAL \refresh_counter[7]~28_combout\ : std_logic;
SIGNAL \Equal1~1_combout\ : std_logic;
SIGNAL \refresh_counter[7]~29\ : std_logic;
SIGNAL \refresh_counter[8]~30_combout\ : std_logic;
SIGNAL \refresh_counter[8]~31\ : std_logic;
SIGNAL \refresh_counter[9]~32_combout\ : std_logic;
SIGNAL \refresh_counter[9]~33\ : std_logic;
SIGNAL \refresh_counter[10]~34_combout\ : std_logic;
SIGNAL \refresh_counter[10]~35\ : std_logic;
SIGNAL \refresh_counter[11]~36_combout\ : std_logic;
SIGNAL \refresh_counter[11]~37\ : std_logic;
SIGNAL \refresh_counter[12]~38_combout\ : std_logic;
SIGNAL \refresh_counter[12]~39\ : std_logic;
SIGNAL \refresh_counter[13]~40_combout\ : std_logic;
SIGNAL \Equal1~2_combout\ : std_logic;
SIGNAL \Equal1~3_combout\ : std_logic;
SIGNAL \blanking~1_combout\ : std_logic;
SIGNAL \refresh_counter[0]~15\ : std_logic;
SIGNAL \refresh_counter[1]~16_combout\ : std_logic;
SIGNAL \refresh_counter[1]~17\ : std_logic;
SIGNAL \refresh_counter[2]~18_combout\ : std_logic;
SIGNAL \refresh_counter[2]~19\ : std_logic;
SIGNAL \refresh_counter[3]~20_combout\ : std_logic;
SIGNAL \Equal1~0_combout\ : std_logic;
SIGNAL \blanking~0_combout\ : std_logic;
SIGNAL \blanking~q\ : std_logic;
SIGNAL \digit_index[0]~1_combout\ : std_logic;
SIGNAL \digit_index[1]~0_combout\ : std_logic;
SIGNAL \digits[12]~input_o\ : std_logic;
SIGNAL \digits[0]~input_o\ : std_logic;
SIGNAL \digits[4]~input_o\ : std_logic;
SIGNAL \Mux3~0_combout\ : std_logic;
SIGNAL \Mux3~1_combout\ : std_logic;
SIGNAL \digits[11]~input_o\ : std_logic;
SIGNAL \digits[15]~input_o\ : std_logic;
SIGNAL \digits[7]~input_o\ : std_logic;
SIGNAL \digits[3]~input_o\ : std_logic;
SIGNAL \Mux0~0_combout\ : std_logic;
SIGNAL \Mux0~1_combout\ : std_logic;
SIGNAL \digits[14]~input_o\ : std_logic;
SIGNAL \digits[10]~input_o\ : std_logic;
SIGNAL \digits[2]~input_o\ : std_logic;
SIGNAL \digits[6]~input_o\ : std_logic;
SIGNAL \Mux1~0_combout\ : std_logic;
SIGNAL \Mux1~1_combout\ : std_logic;
SIGNAL \digits[5]~input_o\ : std_logic;
SIGNAL \digits[13]~input_o\ : std_logic;
SIGNAL \digits[9]~input_o\ : std_logic;
SIGNAL \digits[1]~input_o\ : std_logic;
SIGNAL \Mux2~0_combout\ : std_logic;
SIGNAL \Mux2~1_combout\ : std_logic;
SIGNAL \Mux11~0_combout\ : std_logic;
SIGNAL \Mux10~0_combout\ : std_logic;
SIGNAL \Mux9~0_combout\ : std_logic;
SIGNAL \Mux8~0_combout\ : std_logic;
SIGNAL \Mux7~0_combout\ : std_logic;
SIGNAL \Mux6~0_combout\ : std_logic;
SIGNAL \Mux5~0_combout\ : std_logic;
SIGNAL \dp_in[3]~input_o\ : std_logic;
SIGNAL \dp_in[2]~input_o\ : std_logic;
SIGNAL \dp_in[0]~input_o\ : std_logic;
SIGNAL \Mux4~0_combout\ : std_logic;
SIGNAL \dp_in[1]~input_o\ : std_logic;
SIGNAL \Mux4~1_combout\ : std_logic;
SIGNAL \dp_reg~q\ : std_logic;
SIGNAL \dig_en_reg~0_combout\ : std_logic;
SIGNAL \dig_en_reg~1_combout\ : std_logic;
SIGNAL \dig_en_reg~2_combout\ : std_logic;
SIGNAL \dig_en_reg~3_combout\ : std_logic;
SIGNAL digit_index : std_logic_vector(1 DOWNTO 0);
SIGNAL dig_en_reg : std_logic_vector(3 DOWNTO 0);
SIGNAL refresh_counter : std_logic_vector(13 DOWNTO 0);
SIGNAL seg_reg : std_logic_vector(6 DOWNTO 0);
SIGNAL ALT_INV_dig_en_reg : std_logic_vector(3 DOWNTO 0);
SIGNAL \ALT_INV_dp_reg~q\ : std_logic;
SIGNAL ALT_INV_seg_reg : std_logic_vector(6 DOWNTO 0);

BEGIN

ww_clk <= clk;
ww_reset_n <= reset_n;
ww_digits <= digits;
ww_dp_in <= dp_in;
seg <= ww_seg;
dp <= ww_dp;
dig_en <= ww_dig_en;
ww_devoe <= devoe;
ww_devclrn <= devclrn;
ww_devpor <= devpor;

\clk~inputclkctrl_INCLK_bus\ <= (vcc & vcc & vcc & \clk~input_o\);

\reset_n~inputclkctrl_INCLK_bus\ <= (vcc & vcc & vcc & \reset_n~input_o\);
ALT_INV_dig_en_reg(3) <= NOT dig_en_reg(3);
ALT_INV_dig_en_reg(2) <= NOT dig_en_reg(2);
ALT_INV_dig_en_reg(1) <= NOT dig_en_reg(1);
ALT_INV_dig_en_reg(0) <= NOT dig_en_reg(0);
\ALT_INV_dp_reg~q\ <= NOT \dp_reg~q\;
ALT_INV_seg_reg(6) <= NOT seg_reg(6);
ALT_INV_seg_reg(5) <= NOT seg_reg(5);
ALT_INV_seg_reg(4) <= NOT seg_reg(4);
ALT_INV_seg_reg(3) <= NOT seg_reg(3);
ALT_INV_seg_reg(2) <= NOT seg_reg(2);
ALT_INV_seg_reg(1) <= NOT seg_reg(1);
ALT_INV_seg_reg(0) <= NOT seg_reg(0);

-- Location: IOOBUF_X14_Y29_N16
\seg[0]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(0),
	devoe => ww_devoe,
	o => \seg[0]~output_o\);

-- Location: IOOBUF_X14_Y29_N2
\seg[1]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(1),
	devoe => ww_devoe,
	o => \seg[1]~output_o\);

-- Location: IOOBUF_X14_Y29_N9
\seg[2]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(2),
	devoe => ww_devoe,
	o => \seg[2]~output_o\);

-- Location: IOOBUF_X11_Y29_N2
\seg[3]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(3),
	devoe => ww_devoe,
	o => \seg[3]~output_o\);

-- Location: IOOBUF_X16_Y29_N9
\seg[4]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(4),
	devoe => ww_devoe,
	o => \seg[4]~output_o\);

-- Location: IOOBUF_X16_Y29_N16
\seg[5]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(5),
	devoe => ww_devoe,
	o => \seg[5]~output_o\);

-- Location: IOOBUF_X16_Y29_N2
\seg[6]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_seg_reg(6),
	devoe => ww_devoe,
	o => \seg[6]~output_o\);

-- Location: IOOBUF_X5_Y0_N9
\dp~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_dp_reg~q\,
	devoe => ww_devoe,
	o => \dp~output_o\);

-- Location: IOOBUF_X26_Y29_N9
\dig_en[0]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_dig_en_reg(0),
	devoe => ww_devoe,
	o => \dig_en[0]~output_o\);

-- Location: IOOBUF_X26_Y29_N23
\dig_en[1]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_dig_en_reg(1),
	devoe => ww_devoe,
	o => \dig_en[1]~output_o\);

-- Location: IOOBUF_X26_Y29_N16
\dig_en[2]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_dig_en_reg(2),
	devoe => ww_devoe,
	o => \dig_en[2]~output_o\);

-- Location: IOOBUF_X26_Y29_N2
\dig_en[3]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => ALT_INV_dig_en_reg(3),
	devoe => ww_devoe,
	o => \dig_en[3]~output_o\);

-- Location: IOIBUF_X0_Y14_N1
\clk~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_clk,
	o => \clk~input_o\);

-- Location: CLKCTRL_G4
\clk~inputclkctrl\ : cycloneiii_clkctrl
-- pragma translate_off
GENERIC MAP (
	clock_type => "global clock",
	ena_register_mode => "none")
-- pragma translate_on
PORT MAP (
	inclk => \clk~inputclkctrl_INCLK_bus\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	outclk => \clk~inputclkctrl_outclk\);

-- Location: IOIBUF_X21_Y29_N15
\digits[8]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(8),
	o => \digits[8]~input_o\);

-- Location: LCCOMB_X26_Y25_N4
\refresh_counter[0]~14\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[0]~14_combout\ = refresh_counter(0) $ (VCC)
-- \refresh_counter[0]~15\ = CARRY(refresh_counter(0))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011001111001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(0),
	datad => VCC,
	combout => \refresh_counter[0]~14_combout\,
	cout => \refresh_counter[0]~15\);

-- Location: IOIBUF_X0_Y14_N8
\reset_n~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_reset_n,
	o => \reset_n~input_o\);

-- Location: CLKCTRL_G2
\reset_n~inputclkctrl\ : cycloneiii_clkctrl
-- pragma translate_off
GENERIC MAP (
	clock_type => "global clock",
	ena_register_mode => "none")
-- pragma translate_on
PORT MAP (
	inclk => \reset_n~inputclkctrl_INCLK_bus\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	outclk => \reset_n~inputclkctrl_outclk\);

-- Location: LCCOMB_X26_Y25_N10
\refresh_counter[3]~20\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[3]~20_combout\ = (refresh_counter(3) & (!\refresh_counter[2]~19\)) # (!refresh_counter(3) & ((\refresh_counter[2]~19\) # (GND)))
-- \refresh_counter[3]~21\ = CARRY((!\refresh_counter[2]~19\) # (!refresh_counter(3)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(3),
	datad => VCC,
	cin => \refresh_counter[2]~19\,
	combout => \refresh_counter[3]~20_combout\,
	cout => \refresh_counter[3]~21\);

-- Location: LCCOMB_X26_Y25_N12
\refresh_counter[4]~22\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[4]~22_combout\ = (refresh_counter(4) & (\refresh_counter[3]~21\ $ (GND))) # (!refresh_counter(4) & (!\refresh_counter[3]~21\ & VCC))
-- \refresh_counter[4]~23\ = CARRY((refresh_counter(4) & !\refresh_counter[3]~21\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010010100001010",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(4),
	datad => VCC,
	cin => \refresh_counter[3]~21\,
	combout => \refresh_counter[4]~22_combout\,
	cout => \refresh_counter[4]~23\);

-- Location: FF_X26_Y25_N13
\refresh_counter[4]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[4]~22_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(4));

-- Location: LCCOMB_X26_Y25_N14
\refresh_counter[5]~24\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[5]~24_combout\ = (refresh_counter(5) & (!\refresh_counter[4]~23\)) # (!refresh_counter(5) & ((\refresh_counter[4]~23\) # (GND)))
-- \refresh_counter[5]~25\ = CARRY((!\refresh_counter[4]~23\) # (!refresh_counter(5)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011110000111111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(5),
	datad => VCC,
	cin => \refresh_counter[4]~23\,
	combout => \refresh_counter[5]~24_combout\,
	cout => \refresh_counter[5]~25\);

-- Location: FF_X26_Y25_N15
\refresh_counter[5]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[5]~24_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(5));

-- Location: LCCOMB_X26_Y25_N16
\refresh_counter[6]~26\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[6]~26_combout\ = (refresh_counter(6) & (\refresh_counter[5]~25\ $ (GND))) # (!refresh_counter(6) & (!\refresh_counter[5]~25\ & VCC))
-- \refresh_counter[6]~27\ = CARRY((refresh_counter(6) & !\refresh_counter[5]~25\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(6),
	datad => VCC,
	cin => \refresh_counter[5]~25\,
	combout => \refresh_counter[6]~26_combout\,
	cout => \refresh_counter[6]~27\);

-- Location: FF_X26_Y25_N17
\refresh_counter[6]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[6]~26_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(6));

-- Location: LCCOMB_X26_Y25_N18
\refresh_counter[7]~28\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[7]~28_combout\ = (refresh_counter(7) & (!\refresh_counter[6]~27\)) # (!refresh_counter(7) & ((\refresh_counter[6]~27\) # (GND)))
-- \refresh_counter[7]~29\ = CARRY((!\refresh_counter[6]~27\) # (!refresh_counter(7)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011110000111111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(7),
	datad => VCC,
	cin => \refresh_counter[6]~27\,
	combout => \refresh_counter[7]~28_combout\,
	cout => \refresh_counter[7]~29\);

-- Location: FF_X26_Y25_N19
\refresh_counter[7]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[7]~28_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(7));

-- Location: LCCOMB_X27_Y25_N12
\Equal1~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~1_combout\ = (refresh_counter(4) & (refresh_counter(7) & (refresh_counter(6) & !refresh_counter(5))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000010000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(4),
	datab => refresh_counter(7),
	datac => refresh_counter(6),
	datad => refresh_counter(5),
	combout => \Equal1~1_combout\);

-- Location: LCCOMB_X26_Y25_N20
\refresh_counter[8]~30\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[8]~30_combout\ = (refresh_counter(8) & (\refresh_counter[7]~29\ $ (GND))) # (!refresh_counter(8) & (!\refresh_counter[7]~29\ & VCC))
-- \refresh_counter[8]~31\ = CARRY((refresh_counter(8) & !\refresh_counter[7]~29\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(8),
	datad => VCC,
	cin => \refresh_counter[7]~29\,
	combout => \refresh_counter[8]~30_combout\,
	cout => \refresh_counter[8]~31\);

-- Location: FF_X26_Y25_N21
\refresh_counter[8]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[8]~30_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(8));

-- Location: LCCOMB_X26_Y25_N22
\refresh_counter[9]~32\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[9]~32_combout\ = (refresh_counter(9) & (!\refresh_counter[8]~31\)) # (!refresh_counter(9) & ((\refresh_counter[8]~31\) # (GND)))
-- \refresh_counter[9]~33\ = CARRY((!\refresh_counter[8]~31\) # (!refresh_counter(9)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(9),
	datad => VCC,
	cin => \refresh_counter[8]~31\,
	combout => \refresh_counter[9]~32_combout\,
	cout => \refresh_counter[9]~33\);

-- Location: FF_X26_Y25_N23
\refresh_counter[9]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[9]~32_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(9));

-- Location: LCCOMB_X26_Y25_N24
\refresh_counter[10]~34\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[10]~34_combout\ = (refresh_counter(10) & (\refresh_counter[9]~33\ $ (GND))) # (!refresh_counter(10) & (!\refresh_counter[9]~33\ & VCC))
-- \refresh_counter[10]~35\ = CARRY((refresh_counter(10) & !\refresh_counter[9]~33\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(10),
	datad => VCC,
	cin => \refresh_counter[9]~33\,
	combout => \refresh_counter[10]~34_combout\,
	cout => \refresh_counter[10]~35\);

-- Location: FF_X26_Y25_N25
\refresh_counter[10]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[10]~34_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(10));

-- Location: LCCOMB_X26_Y25_N26
\refresh_counter[11]~36\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[11]~36_combout\ = (refresh_counter(11) & (!\refresh_counter[10]~35\)) # (!refresh_counter(11) & ((\refresh_counter[10]~35\) # (GND)))
-- \refresh_counter[11]~37\ = CARRY((!\refresh_counter[10]~35\) # (!refresh_counter(11)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(11),
	datad => VCC,
	cin => \refresh_counter[10]~35\,
	combout => \refresh_counter[11]~36_combout\,
	cout => \refresh_counter[11]~37\);

-- Location: FF_X26_Y25_N27
\refresh_counter[11]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[11]~36_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(11));

-- Location: LCCOMB_X26_Y25_N28
\refresh_counter[12]~38\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[12]~38_combout\ = (refresh_counter(12) & (\refresh_counter[11]~37\ $ (GND))) # (!refresh_counter(12) & (!\refresh_counter[11]~37\ & VCC))
-- \refresh_counter[12]~39\ = CARRY((refresh_counter(12) & !\refresh_counter[11]~37\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(12),
	datad => VCC,
	cin => \refresh_counter[11]~37\,
	combout => \refresh_counter[12]~38_combout\,
	cout => \refresh_counter[12]~39\);

-- Location: FF_X26_Y25_N29
\refresh_counter[12]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[12]~38_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(12));

-- Location: LCCOMB_X26_Y25_N30
\refresh_counter[13]~40\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[13]~40_combout\ = refresh_counter(13) $ (\refresh_counter[12]~39\)

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011010",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(13),
	cin => \refresh_counter[12]~39\,
	combout => \refresh_counter[13]~40_combout\);

-- Location: FF_X26_Y25_N31
\refresh_counter[13]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[13]~40_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(13));

-- Location: LCCOMB_X27_Y25_N22
\Equal1~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~2_combout\ = (!refresh_counter(11) & (!refresh_counter(10) & (!refresh_counter(8) & !refresh_counter(9))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000000001",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(11),
	datab => refresh_counter(10),
	datac => refresh_counter(8),
	datad => refresh_counter(9),
	combout => \Equal1~2_combout\);

-- Location: LCCOMB_X26_Y25_N0
\Equal1~3\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~3_combout\ = (refresh_counter(12) & (refresh_counter(13) & \Equal1~2_combout\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(12),
	datac => refresh_counter(13),
	datad => \Equal1~2_combout\,
	combout => \Equal1~3_combout\);

-- Location: LCCOMB_X26_Y25_N2
\blanking~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \blanking~1_combout\ = (\blanking~q\) # ((\Equal1~0_combout\ & (\Equal1~1_combout\ & \Equal1~3_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110110011001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal1~0_combout\,
	datab => \blanking~q\,
	datac => \Equal1~1_combout\,
	datad => \Equal1~3_combout\,
	combout => \blanking~1_combout\);

-- Location: FF_X26_Y25_N5
\refresh_counter[0]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[0]~14_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(0));

-- Location: LCCOMB_X26_Y25_N6
\refresh_counter[1]~16\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[1]~16_combout\ = (refresh_counter(1) & (!\refresh_counter[0]~15\)) # (!refresh_counter(1) & ((\refresh_counter[0]~15\) # (GND)))
-- \refresh_counter[1]~17\ = CARRY((!\refresh_counter[0]~15\) # (!refresh_counter(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(1),
	datad => VCC,
	cin => \refresh_counter[0]~15\,
	combout => \refresh_counter[1]~16_combout\,
	cout => \refresh_counter[1]~17\);

-- Location: FF_X26_Y25_N7
\refresh_counter[1]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[1]~16_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(1));

-- Location: LCCOMB_X26_Y25_N8
\refresh_counter[2]~18\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter[2]~18_combout\ = (refresh_counter(2) & (\refresh_counter[1]~17\ $ (GND))) # (!refresh_counter(2) & (!\refresh_counter[1]~17\ & VCC))
-- \refresh_counter[2]~19\ = CARRY((refresh_counter(2) & !\refresh_counter[1]~17\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(2),
	datad => VCC,
	cin => \refresh_counter[1]~17\,
	combout => \refresh_counter[2]~18_combout\,
	cout => \refresh_counter[2]~19\);

-- Location: FF_X26_Y25_N9
\refresh_counter[2]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[2]~18_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(2));

-- Location: FF_X26_Y25_N11
\refresh_counter[3]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter[3]~20_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	sclr => \blanking~1_combout\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(3));

-- Location: LCCOMB_X27_Y25_N30
\Equal1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~0_combout\ = (!refresh_counter(3) & (refresh_counter(1) & (refresh_counter(0) & !refresh_counter(2))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000001000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(3),
	datab => refresh_counter(1),
	datac => refresh_counter(0),
	datad => refresh_counter(2),
	combout => \Equal1~0_combout\);

-- Location: LCCOMB_X27_Y25_N8
\blanking~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \blanking~0_combout\ = (\Equal1~0_combout\ & (\Equal1~1_combout\ & (!\blanking~q\ & \Equal1~3_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000100000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal1~0_combout\,
	datab => \Equal1~1_combout\,
	datac => \blanking~q\,
	datad => \Equal1~3_combout\,
	combout => \blanking~0_combout\);

-- Location: FF_X27_Y25_N9
blanking : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \blanking~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => \blanking~q\);

-- Location: LCCOMB_X22_Y25_N26
\digit_index[0]~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \digit_index[0]~1_combout\ = digit_index(0) $ (\blanking~q\)

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000111111110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => digit_index(0),
	datad => \blanking~q\,
	combout => \digit_index[0]~1_combout\);

-- Location: FF_X22_Y25_N27
\digit_index[0]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \digit_index[0]~1_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => digit_index(0));

-- Location: LCCOMB_X22_Y25_N16
\digit_index[1]~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \digit_index[1]~0_combout\ = digit_index(1) $ (((digit_index(0) & \blanking~q\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(0),
	datac => digit_index(1),
	datad => \blanking~q\,
	combout => \digit_index[1]~0_combout\);

-- Location: FF_X22_Y25_N17
\digit_index[1]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \digit_index[1]~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => digit_index(1));

-- Location: IOIBUF_X16_Y29_N29
\digits[12]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(12),
	o => \digits[12]~input_o\);

-- Location: IOIBUF_X23_Y29_N22
\digits[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(0),
	o => \digits[0]~input_o\);

-- Location: IOIBUF_X23_Y29_N1
\digits[4]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(4),
	o => \digits[4]~input_o\);

-- Location: LCCOMB_X22_Y25_N4
\Mux3~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~0_combout\ = (digit_index(0) & (((\digits[4]~input_o\) # (digit_index(1))))) # (!digit_index(0) & (\digits[0]~input_o\ & ((!digit_index(1)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000011001010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[0]~input_o\,
	datab => \digits[4]~input_o\,
	datac => digit_index(0),
	datad => digit_index(1),
	combout => \Mux3~0_combout\);

-- Location: LCCOMB_X21_Y25_N26
\Mux3~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~1_combout\ = (digit_index(1) & ((\Mux3~0_combout\ & ((\digits[12]~input_o\))) # (!\Mux3~0_combout\ & (\digits[8]~input_o\)))) # (!digit_index(1) & (((\Mux3~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111001110001000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[8]~input_o\,
	datab => digit_index(1),
	datac => \digits[12]~input_o\,
	datad => \Mux3~0_combout\,
	combout => \Mux3~1_combout\);

-- Location: IOIBUF_X21_Y29_N22
\digits[11]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(11),
	o => \digits[11]~input_o\);

-- Location: IOIBUF_X21_Y29_N1
\digits[15]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(15),
	o => \digits[15]~input_o\);

-- Location: IOIBUF_X23_Y29_N29
\digits[7]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(7),
	o => \digits[7]~input_o\);

-- Location: IOIBUF_X23_Y29_N15
\digits[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(3),
	o => \digits[3]~input_o\);

-- Location: LCCOMB_X22_Y25_N6
\Mux0~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~0_combout\ = (digit_index(0) & ((\digits[7]~input_o\) # ((digit_index(1))))) # (!digit_index(0) & (((\digits[3]~input_o\ & !digit_index(1)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000010101100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[7]~input_o\,
	datab => \digits[3]~input_o\,
	datac => digit_index(0),
	datad => digit_index(1),
	combout => \Mux0~0_combout\);

-- Location: LCCOMB_X21_Y25_N20
\Mux0~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~1_combout\ = (digit_index(1) & ((\Mux0~0_combout\ & ((\digits[15]~input_o\))) # (!\Mux0~0_combout\ & (\digits[11]~input_o\)))) # (!digit_index(1) & (((\Mux0~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111001110001000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[11]~input_o\,
	datab => digit_index(1),
	datac => \digits[15]~input_o\,
	datad => \Mux0~0_combout\,
	combout => \Mux0~1_combout\);

-- Location: IOIBUF_X23_Y29_N8
\digits[14]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(14),
	o => \digits[14]~input_o\);

-- Location: IOIBUF_X16_Y29_N22
\digits[10]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(10),
	o => \digits[10]~input_o\);

-- Location: IOIBUF_X14_Y29_N22
\digits[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(2),
	o => \digits[2]~input_o\);

-- Location: IOIBUF_X19_Y29_N29
\digits[6]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(6),
	o => \digits[6]~input_o\);

-- Location: LCCOMB_X21_Y25_N28
\Mux1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & ((\digits[6]~input_o\))) # (!digit_index(0) & (\digits[2]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111110000100010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[2]~input_o\,
	datab => digit_index(1),
	datac => \digits[6]~input_o\,
	datad => digit_index(0),
	combout => \Mux1~0_combout\);

-- Location: LCCOMB_X21_Y25_N30
\Mux1~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~1_combout\ = (digit_index(1) & ((\Mux1~0_combout\ & (\digits[14]~input_o\)) # (!\Mux1~0_combout\ & ((\digits[10]~input_o\))))) # (!digit_index(1) & (((\Mux1~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011101111000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[14]~input_o\,
	datab => digit_index(1),
	datac => \digits[10]~input_o\,
	datad => \Mux1~0_combout\,
	combout => \Mux1~1_combout\);

-- Location: IOIBUF_X14_Y29_N29
\digits[5]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(5),
	o => \digits[5]~input_o\);

-- Location: IOIBUF_X21_Y29_N8
\digits[13]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(13),
	o => \digits[13]~input_o\);

-- Location: IOIBUF_X21_Y29_N29
\digits[9]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(9),
	o => \digits[9]~input_o\);

-- Location: IOIBUF_X11_Y29_N8
\digits[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(1),
	o => \digits[1]~input_o\);

-- Location: LCCOMB_X21_Y25_N8
\Mux2~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~0_combout\ = (digit_index(1) & ((\digits[9]~input_o\) # ((digit_index(0))))) # (!digit_index(1) & (((\digits[1]~input_o\ & !digit_index(0)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100110010111000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[9]~input_o\,
	datab => digit_index(1),
	datac => \digits[1]~input_o\,
	datad => digit_index(0),
	combout => \Mux2~0_combout\);

-- Location: LCCOMB_X21_Y25_N2
\Mux2~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~1_combout\ = (\Mux2~0_combout\ & (((\digits[13]~input_o\) # (!digit_index(0))))) # (!\Mux2~0_combout\ & (\digits[5]~input_o\ & ((digit_index(0)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100101011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[5]~input_o\,
	datab => \digits[13]~input_o\,
	datac => \Mux2~0_combout\,
	datad => digit_index(0),
	combout => \Mux2~1_combout\);

-- Location: LCCOMB_X21_Y25_N4
\Mux11~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux11~0_combout\ = (\Mux0~1_combout\ & ((\Mux1~1_combout\ $ (!\Mux2~1_combout\)) # (!\Mux3~1_combout\))) # (!\Mux0~1_combout\ & ((\Mux2~1_combout\) # (\Mux3~1_combout\ $ (!\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111011101101101",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux11~0_combout\);

-- Location: FF_X21_Y25_N5
\seg_reg[0]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux11~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(0));

-- Location: LCCOMB_X21_Y25_N6
\Mux10~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux10~0_combout\ = (\Mux0~1_combout\ & ((\Mux3~1_combout\ & ((!\Mux2~1_combout\))) # (!\Mux3~1_combout\ & (!\Mux1~1_combout\)))) # (!\Mux0~1_combout\ & ((\Mux3~1_combout\ $ (!\Mux2~1_combout\)) # (!\Mux1~1_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0010011110011111",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux10~0_combout\);

-- Location: FF_X21_Y25_N7
\seg_reg[1]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux10~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(1));

-- Location: LCCOMB_X21_Y25_N12
\Mux9~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux9~0_combout\ = (\Mux0~1_combout\ & (((\Mux3~1_combout\ & !\Mux2~1_combout\)) # (!\Mux1~1_combout\))) # (!\Mux0~1_combout\ & ((\Mux3~1_combout\) # ((\Mux1~1_combout\) # (!\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011111010111111",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux9~0_combout\);

-- Location: FF_X21_Y25_N13
\seg_reg[2]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux9~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(2));

-- Location: LCCOMB_X21_Y25_N10
\Mux8~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux8~0_combout\ = (\Mux2~1_combout\ & ((\Mux3~1_combout\ & ((!\Mux1~1_combout\))) # (!\Mux3~1_combout\ & ((\Mux1~1_combout\) # (!\Mux0~1_combout\))))) # (!\Mux2~1_combout\ & ((\Mux0~1_combout\) # (\Mux3~1_combout\ $ (!\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101111101101",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux8~0_combout\);

-- Location: FF_X21_Y25_N11
\seg_reg[3]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux8~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(3));

-- Location: LCCOMB_X21_Y25_N24
\Mux7~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux7~0_combout\ = (\Mux2~1_combout\ & (((\Mux0~1_combout\)) # (!\Mux3~1_combout\))) # (!\Mux2~1_combout\ & ((\Mux1~1_combout\ & ((\Mux0~1_combout\))) # (!\Mux1~1_combout\ & (!\Mux3~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1101110111000101",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux7~0_combout\);

-- Location: FF_X21_Y25_N25
\seg_reg[4]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux7~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(4));

-- Location: LCCOMB_X21_Y25_N22
\Mux6~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux6~0_combout\ = (\Mux3~1_combout\ & (\Mux0~1_combout\ $ (((\Mux1~1_combout\ & !\Mux2~1_combout\))))) # (!\Mux3~1_combout\ & ((\Mux0~1_combout\) # ((\Mux1~1_combout\) # (!\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1101110001111101",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux6~0_combout\);

-- Location: FF_X21_Y25_N23
\seg_reg[5]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux6~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(5));

-- Location: LCCOMB_X21_Y25_N0
\Mux5~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux5~0_combout\ = (\Mux3~1_combout\ & ((\Mux0~1_combout\) # (\Mux1~1_combout\ $ (\Mux2~1_combout\)))) # (!\Mux3~1_combout\ & ((\Mux2~1_combout\) # (\Mux0~1_combout\ $ (\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1101111110111100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux0~1_combout\,
	datac => \Mux1~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux5~0_combout\);

-- Location: FF_X21_Y25_N1
\seg_reg[6]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux5~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => seg_reg(6));

-- Location: IOIBUF_X28_Y29_N22
\dp_in[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(3),
	o => \dp_in[3]~input_o\);

-- Location: IOIBUF_X26_Y29_N29
\dp_in[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(2),
	o => \dp_in[2]~input_o\);

-- Location: IOIBUF_X28_Y29_N1
\dp_in[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(0),
	o => \dp_in[0]~input_o\);

-- Location: LCCOMB_X27_Y25_N26
\Mux4~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~0_combout\ = (digit_index(1) & ((\dp_in[2]~input_o\) # ((digit_index(0))))) # (!digit_index(1) & (((\dp_in[0]~input_o\ & !digit_index(0)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000010101100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \dp_in[2]~input_o\,
	datab => \dp_in[0]~input_o\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \Mux4~0_combout\);

-- Location: IOIBUF_X28_Y29_N29
\dp_in[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(1),
	o => \dp_in[1]~input_o\);

-- Location: LCCOMB_X27_Y25_N20
\Mux4~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~1_combout\ = (digit_index(0) & ((\Mux4~0_combout\ & (\dp_in[3]~input_o\)) # (!\Mux4~0_combout\ & ((\dp_in[1]~input_o\))))) # (!digit_index(0) & (((\Mux4~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011110010110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \dp_in[3]~input_o\,
	datab => digit_index(0),
	datac => \Mux4~0_combout\,
	datad => \dp_in[1]~input_o\,
	combout => \Mux4~1_combout\);

-- Location: FF_X27_Y25_N21
dp_reg : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Mux4~1_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => \dp_reg~q\);

-- Location: LCCOMB_X27_Y25_N10
\dig_en_reg~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~0_combout\ = (!\blanking~q\ & (!digit_index(1) & !digit_index(0)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000000011",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => \blanking~q\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \dig_en_reg~0_combout\);

-- Location: FF_X27_Y25_N11
\dig_en_reg[0]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \dig_en_reg~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => dig_en_reg(0));

-- Location: LCCOMB_X27_Y25_N16
\dig_en_reg~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~1_combout\ = (!\blanking~q\ & (!digit_index(1) & digit_index(0)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000001100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => \blanking~q\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \dig_en_reg~1_combout\);

-- Location: FF_X27_Y25_N17
\dig_en_reg[1]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \dig_en_reg~1_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => dig_en_reg(1));

-- Location: LCCOMB_X27_Y25_N14
\dig_en_reg~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~2_combout\ = (!\blanking~q\ & (digit_index(1) & !digit_index(0)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => \blanking~q\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \dig_en_reg~2_combout\);

-- Location: FF_X27_Y25_N15
\dig_en_reg[2]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \dig_en_reg~2_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => dig_en_reg(2));

-- Location: LCCOMB_X27_Y25_N24
\dig_en_reg~3\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~3_combout\ = (!\blanking~q\ & (digit_index(1) & digit_index(0)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => \blanking~q\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \dig_en_reg~3_combout\);

-- Location: FF_X27_Y25_N25
\dig_en_reg[3]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \dig_en_reg~3_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => dig_en_reg(3));

ww_seg(0) <= \seg[0]~output_o\;

ww_seg(1) <= \seg[1]~output_o\;

ww_seg(2) <= \seg[2]~output_o\;

ww_seg(3) <= \seg[3]~output_o\;

ww_seg(4) <= \seg[4]~output_o\;

ww_seg(5) <= \seg[5]~output_o\;

ww_seg(6) <= \seg[6]~output_o\;

ww_dp <= \dp~output_o\;

ww_dig_en(0) <= \dig_en[0]~output_o\;

ww_dig_en(1) <= \dig_en[1]~output_o\;

ww_dig_en(2) <= \dig_en[2]~output_o\;

ww_dig_en(3) <= \dig_en[3]~output_o\;
END structure;


