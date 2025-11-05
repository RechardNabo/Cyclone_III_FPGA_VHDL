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

-- DATE "11/05/2025 21:05:28"

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
-- seg[0]	=>  Location: PIN_H22,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[1]	=>  Location: PIN_E22,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[2]	=>  Location: PIN_H21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[3]	=>  Location: PIN_J16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[4]	=>  Location: PIN_F22,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[5]	=>  Location: PIN_K17,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[6]	=>  Location: PIN_E21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp	=>  Location: PIN_AB15,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[0]	=>  Location: PIN_U12,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[1]	=>  Location: PIN_K16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[2]	=>  Location: PIN_AA16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[3]	=>  Location: PIN_AA15,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[8]	=>  Location: PIN_H19,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[4]	=>  Location: PIN_J17,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[0]	=>  Location: PIN_D21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[12]	=>  Location: PIN_G18,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[5]	=>  Location: PIN_F20,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[9]	=>  Location: PIN_H16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[1]	=>  Location: PIN_C22,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[13]	=>  Location: PIN_J21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[10]	=>  Location: PIN_F21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[6]	=>  Location: PIN_H17,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[2]	=>  Location: PIN_F19,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[14]	=>  Location: PIN_H18,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[11]	=>  Location: PIN_K18,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[7]	=>  Location: PIN_J18,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[3]	=>  Location: PIN_D22,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[15]	=>  Location: PIN_H20,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[1]	=>  Location: PIN_AB17,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[2]	=>  Location: PIN_AB16,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[0]	=>  Location: PIN_W14,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[3]	=>  Location: PIN_T12,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- clk	=>  Location: PIN_G21,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- reset_n	=>  Location: PIN_G22,	 I/O Standard: 2.5 V,	 Current Strength: Default


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
SIGNAL \digits[8]~input_o\ : std_logic;
SIGNAL \clk~input_o\ : std_logic;
SIGNAL \clk~inputclkctrl_outclk\ : std_logic;
SIGNAL \Add1~0_combout\ : std_logic;
SIGNAL \reset_n~input_o\ : std_logic;
SIGNAL \reset_n~inputclkctrl_outclk\ : std_logic;
SIGNAL \Add1~1\ : std_logic;
SIGNAL \Add1~2_combout\ : std_logic;
SIGNAL \Add1~3\ : std_logic;
SIGNAL \Add1~4_combout\ : std_logic;
SIGNAL \refresh_counter~5_combout\ : std_logic;
SIGNAL \Add1~5\ : std_logic;
SIGNAL \Add1~6_combout\ : std_logic;
SIGNAL \Add1~7\ : std_logic;
SIGNAL \Add1~8_combout\ : std_logic;
SIGNAL \refresh_counter~4_combout\ : std_logic;
SIGNAL \Add1~9\ : std_logic;
SIGNAL \Add1~10_combout\ : std_logic;
SIGNAL \Equal0~2_combout\ : std_logic;
SIGNAL \Equal0~3_combout\ : std_logic;
SIGNAL \Add1~17\ : std_logic;
SIGNAL \Add1~18_combout\ : std_logic;
SIGNAL \Add1~19\ : std_logic;
SIGNAL \Add1~20_combout\ : std_logic;
SIGNAL \Add1~21\ : std_logic;
SIGNAL \Add1~22_combout\ : std_logic;
SIGNAL \Add1~23\ : std_logic;
SIGNAL \Add1~24_combout\ : std_logic;
SIGNAL \refresh_counter~1_combout\ : std_logic;
SIGNAL \Add1~25\ : std_logic;
SIGNAL \Add1~26_combout\ : std_logic;
SIGNAL \refresh_counter~0_combout\ : std_logic;
SIGNAL \Equal0~0_combout\ : std_logic;
SIGNAL \Add1~11\ : std_logic;
SIGNAL \Add1~12_combout\ : std_logic;
SIGNAL \refresh_counter~3_combout\ : std_logic;
SIGNAL \Add1~13\ : std_logic;
SIGNAL \Add1~14_combout\ : std_logic;
SIGNAL \refresh_counter~2_combout\ : std_logic;
SIGNAL \Add1~15\ : std_logic;
SIGNAL \Add1~16_combout\ : std_logic;
SIGNAL \Equal0~1_combout\ : std_logic;
SIGNAL \digit_index[0]~1_combout\ : std_logic;
SIGNAL \Equal0~4_combout\ : std_logic;
SIGNAL \digit_index[1]~0_combout\ : std_logic;
SIGNAL \digits[0]~input_o\ : std_logic;
SIGNAL \digits[4]~input_o\ : std_logic;
SIGNAL \Mux3~0_combout\ : std_logic;
SIGNAL \digits[12]~input_o\ : std_logic;
SIGNAL \Mux3~1_combout\ : std_logic;
SIGNAL \digits[2]~input_o\ : std_logic;
SIGNAL \digits[6]~input_o\ : std_logic;
SIGNAL \Mux1~0_combout\ : std_logic;
SIGNAL \digits[10]~input_o\ : std_logic;
SIGNAL \digits[14]~input_o\ : std_logic;
SIGNAL \Mux1~1_combout\ : std_logic;
SIGNAL \digits[3]~input_o\ : std_logic;
SIGNAL \digits[7]~input_o\ : std_logic;
SIGNAL \Mux0~0_combout\ : std_logic;
SIGNAL \digits[11]~input_o\ : std_logic;
SIGNAL \digits[15]~input_o\ : std_logic;
SIGNAL \Mux0~1_combout\ : std_logic;
SIGNAL \digits[13]~input_o\ : std_logic;
SIGNAL \digits[9]~input_o\ : std_logic;
SIGNAL \digits[1]~input_o\ : std_logic;
SIGNAL \Mux2~0_combout\ : std_logic;
SIGNAL \digits[5]~input_o\ : std_logic;
SIGNAL \Mux2~1_combout\ : std_logic;
SIGNAL \Mux11~0_combout\ : std_logic;
SIGNAL \Mux10~0_combout\ : std_logic;
SIGNAL \Mux9~0_combout\ : std_logic;
SIGNAL \Mux8~0_combout\ : std_logic;
SIGNAL \Mux7~0_combout\ : std_logic;
SIGNAL \Mux6~0_combout\ : std_logic;
SIGNAL \Mux5~0_combout\ : std_logic;
SIGNAL \dp_in[3]~input_o\ : std_logic;
SIGNAL \dp_in[0]~input_o\ : std_logic;
SIGNAL \dp_in[2]~input_o\ : std_logic;
SIGNAL \Mux4~0_combout\ : std_logic;
SIGNAL \dp_in[1]~input_o\ : std_logic;
SIGNAL \Mux4~1_combout\ : std_logic;
SIGNAL \Mux15~0_combout\ : std_logic;
SIGNAL \Mux13~0_combout\ : std_logic;
SIGNAL \Mux13~1_combout\ : std_logic;
SIGNAL \Mux13~2_combout\ : std_logic;
SIGNAL refresh_counter : std_logic_vector(13 DOWNTO 0);
SIGNAL digit_index : std_logic_vector(1 DOWNTO 0);
SIGNAL \ALT_INV_Mux13~2_combout\ : std_logic;
SIGNAL \ALT_INV_Mux13~1_combout\ : std_logic;
SIGNAL \ALT_INV_Mux13~0_combout\ : std_logic;
SIGNAL \ALT_INV_Mux4~1_combout\ : std_logic;
SIGNAL \ALT_INV_Mux5~0_combout\ : std_logic;

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
\ALT_INV_Mux13~2_combout\ <= NOT \Mux13~2_combout\;
\ALT_INV_Mux13~1_combout\ <= NOT \Mux13~1_combout\;
\ALT_INV_Mux13~0_combout\ <= NOT \Mux13~0_combout\;
\ALT_INV_Mux4~1_combout\ <= NOT \Mux4~1_combout\;
\ALT_INV_Mux5~0_combout\ <= NOT \Mux5~0_combout\;

-- Location: IOOBUF_X41_Y20_N2
\seg[0]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux11~0_combout\,
	devoe => ww_devoe,
	o => \seg[0]~output_o\);

-- Location: IOOBUF_X41_Y23_N16
\seg[1]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux10~0_combout\,
	devoe => ww_devoe,
	o => \seg[1]~output_o\);

-- Location: IOOBUF_X41_Y21_N23
\seg[2]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux9~0_combout\,
	devoe => ww_devoe,
	o => \seg[2]~output_o\);

-- Location: IOOBUF_X41_Y20_N16
\seg[3]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux8~0_combout\,
	devoe => ww_devoe,
	o => \seg[3]~output_o\);

-- Location: IOOBUF_X41_Y22_N23
\seg[4]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux7~0_combout\,
	devoe => ww_devoe,
	o => \seg[4]~output_o\);

-- Location: IOOBUF_X41_Y21_N16
\seg[5]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux6~0_combout\,
	devoe => ww_devoe,
	o => \seg[5]~output_o\);

-- Location: IOOBUF_X41_Y23_N9
\seg[6]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_Mux5~0_combout\,
	devoe => ww_devoe,
	o => \seg[6]~output_o\);

-- Location: IOOBUF_X26_Y0_N9
\dp~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_Mux4~1_combout\,
	devoe => ww_devoe,
	o => \dp~output_o\);

-- Location: IOOBUF_X26_Y0_N2
\dig_en[0]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \Mux15~0_combout\,
	devoe => ww_devoe,
	o => \dig_en[0]~output_o\);

-- Location: IOOBUF_X41_Y20_N9
\dig_en[1]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_Mux13~0_combout\,
	devoe => ww_devoe,
	o => \dig_en[1]~output_o\);

-- Location: IOOBUF_X28_Y0_N23
\dig_en[2]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_Mux13~1_combout\,
	devoe => ww_devoe,
	o => \dig_en[2]~output_o\);

-- Location: IOOBUF_X26_Y0_N16
\dig_en[3]~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_Mux13~2_combout\,
	devoe => ww_devoe,
	o => \dig_en[3]~output_o\);

-- Location: IOIBUF_X41_Y23_N22
\digits[8]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(8),
	o => \digits[8]~input_o\);

-- Location: IOIBUF_X41_Y15_N1
\clk~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_clk,
	o => \clk~input_o\);

-- Location: CLKCTRL_G9
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

-- Location: LCCOMB_X27_Y3_N4
\Add1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~0_combout\ = refresh_counter(0) $ (VCC)
-- \Add1~1\ = CARRY(refresh_counter(0))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011001111001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(0),
	datad => VCC,
	combout => \Add1~0_combout\,
	cout => \Add1~1\);

-- Location: IOIBUF_X41_Y15_N8
\reset_n~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_reset_n,
	o => \reset_n~input_o\);

-- Location: CLKCTRL_G7
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

-- Location: FF_X27_Y3_N5
\refresh_counter[0]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(0));

-- Location: LCCOMB_X27_Y3_N6
\Add1~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~2_combout\ = (refresh_counter(1) & (!\Add1~1\)) # (!refresh_counter(1) & ((\Add1~1\) # (GND)))
-- \Add1~3\ = CARRY((!\Add1~1\) # (!refresh_counter(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(1),
	datad => VCC,
	cin => \Add1~1\,
	combout => \Add1~2_combout\,
	cout => \Add1~3\);

-- Location: FF_X27_Y3_N7
\refresh_counter[1]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~2_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(1));

-- Location: LCCOMB_X27_Y3_N8
\Add1~4\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~4_combout\ = (refresh_counter(2) & (\Add1~3\ $ (GND))) # (!refresh_counter(2) & (!\Add1~3\ & VCC))
-- \Add1~5\ = CARRY((refresh_counter(2) & !\Add1~3\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(2),
	datad => VCC,
	cin => \Add1~3\,
	combout => \Add1~4_combout\,
	cout => \Add1~5\);

-- Location: LCCOMB_X27_Y3_N2
\refresh_counter~5\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~5_combout\ = (\Add1~4_combout\ & (((!\Equal0~3_combout\) # (!\Equal0~1_combout\)) # (!\Equal0~0_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0100110011001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datab => \Add1~4_combout\,
	datac => \Equal0~1_combout\,
	datad => \Equal0~3_combout\,
	combout => \refresh_counter~5_combout\);

-- Location: FF_X27_Y3_N3
\refresh_counter[2]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~5_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(2));

-- Location: LCCOMB_X27_Y3_N10
\Add1~6\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~6_combout\ = (refresh_counter(3) & (!\Add1~5\)) # (!refresh_counter(3) & ((\Add1~5\) # (GND)))
-- \Add1~7\ = CARRY((!\Add1~5\) # (!refresh_counter(3)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(3),
	datad => VCC,
	cin => \Add1~5\,
	combout => \Add1~6_combout\,
	cout => \Add1~7\);

-- Location: FF_X27_Y3_N11
\refresh_counter[3]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~6_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(3));

-- Location: LCCOMB_X27_Y3_N12
\Add1~8\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~8_combout\ = (refresh_counter(4) & (\Add1~7\ $ (GND))) # (!refresh_counter(4) & (!\Add1~7\ & VCC))
-- \Add1~9\ = CARRY((refresh_counter(4) & !\Add1~7\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010010100001010",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(4),
	datad => VCC,
	cin => \Add1~7\,
	combout => \Add1~8_combout\,
	cout => \Add1~9\);

-- Location: LCCOMB_X28_Y3_N20
\refresh_counter~4\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~4_combout\ = (\Add1~8_combout\ & (((!\Equal0~1_combout\) # (!\Equal0~3_combout\)) # (!\Equal0~0_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111111100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datab => \Equal0~3_combout\,
	datac => \Equal0~1_combout\,
	datad => \Add1~8_combout\,
	combout => \refresh_counter~4_combout\);

-- Location: FF_X28_Y3_N21
\refresh_counter[4]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~4_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(4));

-- Location: LCCOMB_X27_Y3_N14
\Add1~10\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~10_combout\ = (refresh_counter(5) & (!\Add1~9\)) # (!refresh_counter(5) & ((\Add1~9\) # (GND)))
-- \Add1~11\ = CARRY((!\Add1~9\) # (!refresh_counter(5)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011110000111111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(5),
	datad => VCC,
	cin => \Add1~9\,
	combout => \Add1~10_combout\,
	cout => \Add1~11\);

-- Location: FF_X27_Y3_N15
\refresh_counter[5]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~10_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(5));

-- Location: LCCOMB_X28_Y3_N18
\Equal0~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal0~2_combout\ = (!refresh_counter(3) & (refresh_counter(4) & (!refresh_counter(2) & !refresh_counter(5))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000000100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(3),
	datab => refresh_counter(4),
	datac => refresh_counter(2),
	datad => refresh_counter(5),
	combout => \Equal0~2_combout\);

-- Location: LCCOMB_X28_Y3_N16
\Equal0~3\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal0~3_combout\ = (refresh_counter(0) & (refresh_counter(1) & \Equal0~2_combout\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(0),
	datac => refresh_counter(1),
	datad => \Equal0~2_combout\,
	combout => \Equal0~3_combout\);

-- Location: LCCOMB_X27_Y3_N20
\Add1~16\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~16_combout\ = (refresh_counter(8) & (\Add1~15\ $ (GND))) # (!refresh_counter(8) & (!\Add1~15\ & VCC))
-- \Add1~17\ = CARRY((refresh_counter(8) & !\Add1~15\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(8),
	datad => VCC,
	cin => \Add1~15\,
	combout => \Add1~16_combout\,
	cout => \Add1~17\);

-- Location: LCCOMB_X27_Y3_N22
\Add1~18\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~18_combout\ = (refresh_counter(9) & (!\Add1~17\)) # (!refresh_counter(9) & ((\Add1~17\) # (GND)))
-- \Add1~19\ = CARRY((!\Add1~17\) # (!refresh_counter(9)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(9),
	datad => VCC,
	cin => \Add1~17\,
	combout => \Add1~18_combout\,
	cout => \Add1~19\);

-- Location: FF_X27_Y3_N23
\refresh_counter[9]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~18_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(9));

-- Location: LCCOMB_X27_Y3_N24
\Add1~20\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~20_combout\ = (refresh_counter(10) & (\Add1~19\ $ (GND))) # (!refresh_counter(10) & (!\Add1~19\ & VCC))
-- \Add1~21\ = CARRY((refresh_counter(10) & !\Add1~19\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(10),
	datad => VCC,
	cin => \Add1~19\,
	combout => \Add1~20_combout\,
	cout => \Add1~21\);

-- Location: FF_X27_Y3_N25
\refresh_counter[10]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~20_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(10));

-- Location: LCCOMB_X27_Y3_N26
\Add1~22\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~22_combout\ = (refresh_counter(11) & (!\Add1~21\)) # (!refresh_counter(11) & ((\Add1~21\) # (GND)))
-- \Add1~23\ = CARRY((!\Add1~21\) # (!refresh_counter(11)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101001011111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(11),
	datad => VCC,
	cin => \Add1~21\,
	combout => \Add1~22_combout\,
	cout => \Add1~23\);

-- Location: FF_X27_Y3_N27
\refresh_counter[11]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~22_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(11));

-- Location: LCCOMB_X27_Y3_N28
\Add1~24\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~24_combout\ = (refresh_counter(12) & (\Add1~23\ $ (GND))) # (!refresh_counter(12) & (!\Add1~23\ & VCC))
-- \Add1~25\ = CARRY((refresh_counter(12) & !\Add1~23\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010010100001010",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(12),
	datad => VCC,
	cin => \Add1~23\,
	combout => \Add1~24_combout\,
	cout => \Add1~25\);

-- Location: LCCOMB_X28_Y3_N4
\refresh_counter~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~1_combout\ = (\Add1~24_combout\ & (((!\Equal0~1_combout\) # (!\Equal0~3_combout\)) # (!\Equal0~0_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111111100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datab => \Equal0~3_combout\,
	datac => \Equal0~1_combout\,
	datad => \Add1~24_combout\,
	combout => \refresh_counter~1_combout\);

-- Location: FF_X28_Y3_N5
\refresh_counter[12]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~1_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(12));

-- Location: LCCOMB_X27_Y3_N30
\Add1~26\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~26_combout\ = \Add1~25\ $ (refresh_counter(13))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000111111110000",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datad => refresh_counter(13),
	cin => \Add1~25\,
	combout => \Add1~26_combout\);

-- Location: LCCOMB_X28_Y3_N22
\refresh_counter~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~0_combout\ = (\Add1~26_combout\ & (((!\Equal0~1_combout\) # (!\Equal0~3_combout\)) # (!\Equal0~0_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111111100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datab => \Equal0~3_combout\,
	datac => \Equal0~1_combout\,
	datad => \Add1~26_combout\,
	combout => \refresh_counter~0_combout\);

-- Location: FF_X28_Y3_N23
\refresh_counter[13]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~0_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(13));

-- Location: LCCOMB_X28_Y3_N6
\Equal0~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal0~0_combout\ = (refresh_counter(13) & (refresh_counter(12) & (!refresh_counter(11) & !refresh_counter(10))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000001000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(13),
	datab => refresh_counter(12),
	datac => refresh_counter(11),
	datad => refresh_counter(10),
	combout => \Equal0~0_combout\);

-- Location: LCCOMB_X27_Y3_N16
\Add1~12\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~12_combout\ = (refresh_counter(6) & (\Add1~11\ $ (GND))) # (!refresh_counter(6) & (!\Add1~11\ & VCC))
-- \Add1~13\ = CARRY((refresh_counter(6) & !\Add1~11\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100001100001100",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(6),
	datad => VCC,
	cin => \Add1~11\,
	combout => \Add1~12_combout\,
	cout => \Add1~13\);

-- Location: LCCOMB_X28_Y3_N24
\refresh_counter~3\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~3_combout\ = (\Add1~12_combout\ & (((!\Equal0~0_combout\) # (!\Equal0~3_combout\)) # (!\Equal0~1_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111000011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~1_combout\,
	datab => \Equal0~3_combout\,
	datac => \Add1~12_combout\,
	datad => \Equal0~0_combout\,
	combout => \refresh_counter~3_combout\);

-- Location: FF_X28_Y3_N25
\refresh_counter[6]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~3_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(6));

-- Location: LCCOMB_X27_Y3_N18
\Add1~14\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Add1~14_combout\ = (refresh_counter(7) & (!\Add1~13\)) # (!refresh_counter(7) & ((\Add1~13\) # (GND)))
-- \Add1~15\ = CARRY((!\Add1~13\) # (!refresh_counter(7)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011110000111111",
	sum_lutc_input => "cin")
-- pragma translate_on
PORT MAP (
	datab => refresh_counter(7),
	datad => VCC,
	cin => \Add1~13\,
	combout => \Add1~14_combout\,
	cout => \Add1~15\);

-- Location: LCCOMB_X27_Y3_N0
\refresh_counter~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \refresh_counter~2_combout\ = (\Add1~14_combout\ & (((!\Equal0~1_combout\) # (!\Equal0~3_combout\)) # (!\Equal0~0_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111111100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datab => \Equal0~3_combout\,
	datac => \Equal0~1_combout\,
	datad => \Add1~14_combout\,
	combout => \refresh_counter~2_combout\);

-- Location: FF_X27_Y3_N1
\refresh_counter[7]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \refresh_counter~2_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(7));

-- Location: FF_X27_Y3_N21
\refresh_counter[8]\ : dffeas
-- pragma translate_off
GENERIC MAP (
	is_wysiwyg => "true",
	power_up => "low")
-- pragma translate_on
PORT MAP (
	clk => \clk~inputclkctrl_outclk\,
	d => \Add1~16_combout\,
	clrn => \reset_n~inputclkctrl_outclk\,
	devclrn => ww_devclrn,
	devpor => ww_devpor,
	q => refresh_counter(8));

-- Location: LCCOMB_X28_Y3_N30
\Equal0~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal0~1_combout\ = (!refresh_counter(8) & (refresh_counter(6) & (refresh_counter(7) & !refresh_counter(9))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000001000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(8),
	datab => refresh_counter(6),
	datac => refresh_counter(7),
	datad => refresh_counter(9),
	combout => \Equal0~1_combout\);

-- Location: LCCOMB_X28_Y3_N26
\digit_index[0]~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \digit_index[0]~1_combout\ = digit_index(0) $ (((\Equal0~1_combout\ & (\Equal0~3_combout\ & \Equal0~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0111100011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~1_combout\,
	datab => \Equal0~3_combout\,
	datac => digit_index(0),
	datad => \Equal0~0_combout\,
	combout => \digit_index[0]~1_combout\);

-- Location: FF_X28_Y3_N27
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

-- Location: LCCOMB_X28_Y3_N2
\Equal0~4\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal0~4_combout\ = (\Equal0~0_combout\ & (\Equal0~1_combout\ & \Equal0~3_combout\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Equal0~0_combout\,
	datac => \Equal0~1_combout\,
	datad => \Equal0~3_combout\,
	combout => \Equal0~4_combout\);

-- Location: LCCOMB_X28_Y3_N12
\digit_index[1]~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \digit_index[1]~0_combout\ = digit_index(1) $ (((digit_index(0) & \Equal0~4_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101101011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(0),
	datac => digit_index(1),
	datad => \Equal0~4_combout\,
	combout => \digit_index[1]~0_combout\);

-- Location: FF_X28_Y3_N13
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

-- Location: IOIBUF_X41_Y24_N1
\digits[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(0),
	o => \digits[0]~input_o\);

-- Location: IOIBUF_X41_Y24_N22
\digits[4]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(4),
	o => \digits[4]~input_o\);

-- Location: LCCOMB_X40_Y21_N20
\Mux3~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & ((\digits[4]~input_o\))) # (!digit_index(0) & (\digits[0]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111010010100100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datab => \digits[0]~input_o\,
	datac => digit_index(0),
	datad => \digits[4]~input_o\,
	combout => \Mux3~0_combout\);

-- Location: IOIBUF_X41_Y25_N8
\digits[12]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(12),
	o => \digits[12]~input_o\);

-- Location: LCCOMB_X40_Y21_N10
\Mux3~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~1_combout\ = (\Mux3~0_combout\ & (((\digits[12]~input_o\) # (!digit_index(1))))) # (!\Mux3~0_combout\ & (\digits[8]~input_o\ & (digit_index(1))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110110000101100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[8]~input_o\,
	datab => \Mux3~0_combout\,
	datac => digit_index(1),
	datad => \digits[12]~input_o\,
	combout => \Mux3~1_combout\);

-- Location: IOIBUF_X41_Y25_N15
\digits[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(2),
	o => \digits[2]~input_o\);

-- Location: IOIBUF_X41_Y25_N1
\digits[6]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(6),
	o => \digits[6]~input_o\);

-- Location: LCCOMB_X40_Y21_N24
\Mux1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & ((\digits[6]~input_o\))) # (!digit_index(0) & (\digits[2]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111010010100100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datab => \digits[2]~input_o\,
	datac => digit_index(0),
	datad => \digits[6]~input_o\,
	combout => \Mux1~0_combout\);

-- Location: IOIBUF_X41_Y22_N15
\digits[10]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(10),
	o => \digits[10]~input_o\);

-- Location: IOIBUF_X41_Y23_N1
\digits[14]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(14),
	o => \digits[14]~input_o\);

-- Location: LCCOMB_X40_Y21_N18
\Mux1~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~1_combout\ = (digit_index(1) & ((\Mux1~0_combout\ & ((\digits[14]~input_o\))) # (!\Mux1~0_combout\ & (\digits[10]~input_o\)))) # (!digit_index(1) & (\Mux1~0_combout\))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110110001100100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datab => \Mux1~0_combout\,
	datac => \digits[10]~input_o\,
	datad => \digits[14]~input_o\,
	combout => \Mux1~1_combout\);

-- Location: IOIBUF_X41_Y24_N8
\digits[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(3),
	o => \digits[3]~input_o\);

-- Location: IOIBUF_X41_Y21_N1
\digits[7]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(7),
	o => \digits[7]~input_o\);

-- Location: LCCOMB_X40_Y21_N12
\Mux0~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~0_combout\ = (digit_index(1) & (digit_index(0))) # (!digit_index(1) & ((digit_index(0) & ((\digits[7]~input_o\))) # (!digit_index(0) & (\digits[3]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1101110010011000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datab => digit_index(0),
	datac => \digits[3]~input_o\,
	datad => \digits[7]~input_o\,
	combout => \Mux0~0_combout\);

-- Location: IOIBUF_X41_Y21_N8
\digits[11]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(11),
	o => \digits[11]~input_o\);

-- Location: IOIBUF_X41_Y22_N1
\digits[15]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(15),
	o => \digits[15]~input_o\);

-- Location: LCCOMB_X40_Y21_N14
\Mux0~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~1_combout\ = (\Mux0~0_combout\ & (((\digits[15]~input_o\) # (!digit_index(1))))) # (!\Mux0~0_combout\ & (\digits[11]~input_o\ & (digit_index(1))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110101001001010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~0_combout\,
	datab => \digits[11]~input_o\,
	datac => digit_index(1),
	datad => \digits[15]~input_o\,
	combout => \Mux0~1_combout\);

-- Location: IOIBUF_X41_Y20_N22
\digits[13]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(13),
	o => \digits[13]~input_o\);

-- Location: IOIBUF_X41_Y24_N15
\digits[9]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(9),
	o => \digits[9]~input_o\);

-- Location: IOIBUF_X41_Y26_N22
\digits[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(1),
	o => \digits[1]~input_o\);

-- Location: LCCOMB_X40_Y21_N28
\Mux2~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~0_combout\ = (digit_index(1) & ((digit_index(0)) # ((\digits[9]~input_o\)))) # (!digit_index(1) & (!digit_index(0) & ((\digits[1]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011100110101000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datab => digit_index(0),
	datac => \digits[9]~input_o\,
	datad => \digits[1]~input_o\,
	combout => \Mux2~0_combout\);

-- Location: IOIBUF_X41_Y25_N22
\digits[5]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(5),
	o => \digits[5]~input_o\);

-- Location: LCCOMB_X40_Y21_N6
\Mux2~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~1_combout\ = (\Mux2~0_combout\ & ((\digits[13]~input_o\) # ((!digit_index(0))))) # (!\Mux2~0_combout\ & (((digit_index(0) & \digits[5]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011110010001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[13]~input_o\,
	datab => \Mux2~0_combout\,
	datac => digit_index(0),
	datad => \digits[5]~input_o\,
	combout => \Mux2~1_combout\);

-- Location: LCCOMB_X40_Y21_N8
\Mux11~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux11~0_combout\ = (\Mux1~1_combout\ & (!\Mux2~1_combout\ & (\Mux3~1_combout\ $ (!\Mux0~1_combout\)))) # (!\Mux1~1_combout\ & (\Mux3~1_combout\ & (\Mux0~1_combout\ $ (!\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0010000010000110",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux11~0_combout\);

-- Location: LCCOMB_X40_Y21_N2
\Mux10~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux10~0_combout\ = (\Mux0~1_combout\ & ((\Mux3~1_combout\ & ((\Mux2~1_combout\))) # (!\Mux3~1_combout\ & (\Mux1~1_combout\)))) # (!\Mux0~1_combout\ & (\Mux1~1_combout\ & (\Mux3~1_combout\ $ (\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110010001001000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux10~0_combout\);

-- Location: LCCOMB_X40_Y21_N16
\Mux9~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux9~0_combout\ = (\Mux1~1_combout\ & (\Mux0~1_combout\ & ((\Mux2~1_combout\) # (!\Mux3~1_combout\)))) # (!\Mux1~1_combout\ & (!\Mux3~1_combout\ & (!\Mux0~1_combout\ & \Mux2~1_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100000101000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux9~0_combout\);

-- Location: LCCOMB_X40_Y21_N30
\Mux8~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux8~0_combout\ = (\Mux2~1_combout\ & ((\Mux3~1_combout\ & (\Mux1~1_combout\)) # (!\Mux3~1_combout\ & (!\Mux1~1_combout\ & \Mux0~1_combout\)))) # (!\Mux2~1_combout\ & (!\Mux0~1_combout\ & (\Mux3~1_combout\ $ (\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1001100000000110",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux8~0_combout\);

-- Location: LCCOMB_X40_Y21_N0
\Mux7~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux7~0_combout\ = (\Mux2~1_combout\ & (\Mux3~1_combout\ & ((!\Mux0~1_combout\)))) # (!\Mux2~1_combout\ & ((\Mux1~1_combout\ & ((!\Mux0~1_combout\))) # (!\Mux1~1_combout\ & (\Mux3~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000101000101110",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux7~0_combout\);

-- Location: LCCOMB_X40_Y21_N22
\Mux6~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux6~0_combout\ = (\Mux3~1_combout\ & (\Mux0~1_combout\ $ (((\Mux2~1_combout\) # (!\Mux1~1_combout\))))) # (!\Mux3~1_combout\ & (!\Mux1~1_combout\ & (!\Mux0~1_combout\ & \Mux2~1_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000101110000010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux6~0_combout\);

-- Location: LCCOMB_X40_Y21_N4
\Mux5~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux5~0_combout\ = (\Mux3~1_combout\ & ((\Mux0~1_combout\) # (\Mux1~1_combout\ $ (\Mux2~1_combout\)))) # (!\Mux3~1_combout\ & ((\Mux2~1_combout\) # (\Mux1~1_combout\ $ (\Mux0~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111011110111100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux3~1_combout\,
	datab => \Mux1~1_combout\,
	datac => \Mux0~1_combout\,
	datad => \Mux2~1_combout\,
	combout => \Mux5~0_combout\);

-- Location: IOIBUF_X28_Y0_N29
\dp_in[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(3),
	o => \dp_in[3]~input_o\);

-- Location: IOIBUF_X30_Y0_N15
\dp_in[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(0),
	o => \dp_in[0]~input_o\);

-- Location: IOIBUF_X28_Y0_N15
\dp_in[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(2),
	o => \dp_in[2]~input_o\);

-- Location: LCCOMB_X28_Y3_N0
\Mux4~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~0_combout\ = (digit_index(0) & (((digit_index(1))))) # (!digit_index(0) & ((digit_index(1) & ((\dp_in[2]~input_o\))) # (!digit_index(1) & (\dp_in[0]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111101001000100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(0),
	datab => \dp_in[0]~input_o\,
	datac => \dp_in[2]~input_o\,
	datad => digit_index(1),
	combout => \Mux4~0_combout\);

-- Location: IOIBUF_X28_Y0_N1
\dp_in[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(1),
	o => \dp_in[1]~input_o\);

-- Location: LCCOMB_X28_Y3_N10
\Mux4~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~1_combout\ = (\Mux4~0_combout\ & ((\dp_in[3]~input_o\) # ((!digit_index(0))))) # (!\Mux4~0_combout\ & (((digit_index(0) & \dp_in[1]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011110010001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \dp_in[3]~input_o\,
	datab => \Mux4~0_combout\,
	datac => digit_index(0),
	datad => \dp_in[1]~input_o\,
	combout => \Mux4~1_combout\);

-- Location: LCCOMB_X28_Y3_N8
\Mux15~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux15~0_combout\ = (digit_index(0)) # (digit_index(1))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111111111110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => digit_index(0),
	datad => digit_index(1),
	combout => \Mux15~0_combout\);

-- Location: LCCOMB_X40_Y21_N26
\Mux13~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux13~0_combout\ = (!digit_index(1) & digit_index(0))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101000001010000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(1),
	datac => digit_index(0),
	combout => \Mux13~0_combout\);

-- Location: LCCOMB_X28_Y3_N14
\Mux13~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux13~1_combout\ = (!digit_index(0) & digit_index(1))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000111100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => digit_index(0),
	datad => digit_index(1),
	combout => \Mux13~1_combout\);

-- Location: LCCOMB_X28_Y3_N28
\Mux13~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux13~2_combout\ = (digit_index(0) & digit_index(1))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => digit_index(0),
	datad => digit_index(1),
	combout => \Mux13~2_combout\);

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


