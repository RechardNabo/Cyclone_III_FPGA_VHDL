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

-- DATE "11/06/2025 20:35:43"

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
-- seg[0]	=>  Location: PIN_Y7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[1]	=>  Location: PIN_U9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[2]	=>  Location: PIN_U10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[3]	=>  Location: PIN_AB10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[4]	=>  Location: PIN_AB4,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[5]	=>  Location: PIN_V10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- seg[6]	=>  Location: PIN_AB3,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp	=>  Location: PIN_Y6,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[0]	=>  Location: PIN_Y8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[1]	=>  Location: PIN_AA4,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[2]	=>  Location: PIN_AA7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dig_en[3]	=>  Location: PIN_V7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[8]	=>  Location: PIN_U11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[4]	=>  Location: PIN_AA9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[0]	=>  Location: PIN_V11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[12]	=>  Location: PIN_T10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[5]	=>  Location: PIN_AB8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[9]	=>  Location: PIN_AA10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[1]	=>  Location: PIN_W10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[13]	=>  Location: PIN_W8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[10]	=>  Location: PIN_Y10,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[6]	=>  Location: PIN_W6,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[2]	=>  Location: PIN_AA14,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[14]	=>  Location: PIN_T11,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[11]	=>  Location: PIN_AB9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[7]	=>  Location: PIN_V8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[3]	=>  Location: PIN_AA8,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- digits[15]	=>  Location: PIN_V9,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- clk	=>  Location: PIN_G2,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- reset_n	=>  Location: PIN_G1,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[1]	=>  Location: PIN_W7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[2]	=>  Location: PIN_AA5,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[0]	=>  Location: PIN_AB7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- dp_in[3]	=>  Location: PIN_AB5,	 I/O Standard: 2.5 V,	 Current Strength: Default


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
SIGNAL \digits[15]~input_o\ : std_logic;
SIGNAL \digits[11]~input_o\ : std_logic;
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
SIGNAL \digits[7]~input_o\ : std_logic;
SIGNAL \digits[3]~input_o\ : std_logic;
SIGNAL \Mux0~0_combout\ : std_logic;
SIGNAL \Mux0~1_combout\ : std_logic;
SIGNAL \digits[12]~input_o\ : std_logic;
SIGNAL \digits[8]~input_o\ : std_logic;
SIGNAL \digits[0]~input_o\ : std_logic;
SIGNAL \digits[4]~input_o\ : std_logic;
SIGNAL \Mux3~0_combout\ : std_logic;
SIGNAL \Mux3~1_combout\ : std_logic;
SIGNAL \digits[5]~input_o\ : std_logic;
SIGNAL \digits[13]~input_o\ : std_logic;
SIGNAL \digits[1]~input_o\ : std_logic;
SIGNAL \digits[9]~input_o\ : std_logic;
SIGNAL \Mux2~0_combout\ : std_logic;
SIGNAL \Mux2~1_combout\ : std_logic;
SIGNAL \digits[10]~input_o\ : std_logic;
SIGNAL \digits[14]~input_o\ : std_logic;
SIGNAL \digits[2]~input_o\ : std_logic;
SIGNAL \digits[6]~input_o\ : std_logic;
SIGNAL \Mux1~0_combout\ : std_logic;
SIGNAL \Mux1~1_combout\ : std_logic;
SIGNAL \Mux11~0_combout\ : std_logic;
SIGNAL \Mux10~0_combout\ : std_logic;
SIGNAL \Mux9~0_combout\ : std_logic;
SIGNAL \Mux8~0_combout\ : std_logic;
SIGNAL \Mux7~0_combout\ : std_logic;
SIGNAL \Mux6~0_combout\ : std_logic;
SIGNAL \Mux5~0_combout\ : std_logic;
SIGNAL \dp_in[1]~input_o\ : std_logic;
SIGNAL \dp_in[3]~input_o\ : std_logic;
SIGNAL \dp_in[0]~input_o\ : std_logic;
SIGNAL \dp_in[2]~input_o\ : std_logic;
SIGNAL \Mux4~0_combout\ : std_logic;
SIGNAL \Mux4~1_combout\ : std_logic;
SIGNAL \dp_reg~q\ : std_logic;
SIGNAL \dig_en_reg~0_combout\ : std_logic;
SIGNAL \dig_en_reg~1_combout\ : std_logic;
SIGNAL \dig_en_reg~2_combout\ : std_logic;
SIGNAL \dig_en_reg~3_combout\ : std_logic;
SIGNAL seg_reg : std_logic_vector(6 DOWNTO 0);
SIGNAL refresh_counter : std_logic_vector(13 DOWNTO 0);
SIGNAL digit_index : std_logic_vector(1 DOWNTO 0);
SIGNAL dig_en_reg : std_logic_vector(3 DOWNTO 0);
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

-- Location: IOOBUF_X9_Y0_N9
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

-- Location: IOOBUF_X9_Y0_N2
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

-- Location: IOOBUF_X14_Y0_N2
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

-- Location: IOOBUF_X21_Y0_N30
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

-- Location: IOOBUF_X7_Y0_N2
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

-- Location: IOOBUF_X14_Y0_N16
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

-- Location: IOOBUF_X7_Y0_N30
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

-- Location: IOOBUF_X11_Y0_N2
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

-- Location: IOOBUF_X7_Y0_N9
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

-- Location: IOOBUF_X11_Y0_N16
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

-- Location: IOOBUF_X7_Y0_N16
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

-- Location: IOIBUF_X14_Y0_N22
\digits[15]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(15),
	o => \digits[15]~input_o\);

-- Location: IOIBUF_X16_Y0_N1
\digits[11]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(11),
	o => \digits[11]~input_o\);

-- Location: LCCOMB_X11_Y1_N4
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

-- Location: LCCOMB_X11_Y1_N10
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

-- Location: LCCOMB_X11_Y1_N12
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

-- Location: FF_X11_Y1_N13
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

-- Location: LCCOMB_X11_Y1_N14
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

-- Location: FF_X11_Y1_N15
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

-- Location: LCCOMB_X11_Y1_N16
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

-- Location: FF_X11_Y1_N17
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

-- Location: LCCOMB_X11_Y1_N18
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

-- Location: FF_X11_Y1_N19
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

-- Location: LCCOMB_X10_Y1_N16
\Equal1~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~1_combout\ = (refresh_counter(7) & (refresh_counter(4) & (!refresh_counter(5) & refresh_counter(6))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000100000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(7),
	datab => refresh_counter(4),
	datac => refresh_counter(5),
	datad => refresh_counter(6),
	combout => \Equal1~1_combout\);

-- Location: LCCOMB_X11_Y1_N20
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

-- Location: FF_X11_Y1_N21
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

-- Location: LCCOMB_X11_Y1_N22
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

-- Location: FF_X11_Y1_N23
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

-- Location: LCCOMB_X11_Y1_N24
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

-- Location: FF_X11_Y1_N25
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

-- Location: LCCOMB_X11_Y1_N26
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

-- Location: FF_X11_Y1_N27
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

-- Location: LCCOMB_X11_Y1_N28
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

-- Location: FF_X11_Y1_N29
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

-- Location: LCCOMB_X11_Y1_N30
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

-- Location: FF_X11_Y1_N31
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

-- Location: LCCOMB_X10_Y1_N14
\Equal1~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~2_combout\ = (!refresh_counter(8) & (!refresh_counter(9) & (!refresh_counter(10) & !refresh_counter(11))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000000001",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(8),
	datab => refresh_counter(9),
	datac => refresh_counter(10),
	datad => refresh_counter(11),
	combout => \Equal1~2_combout\);

-- Location: LCCOMB_X11_Y1_N0
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

-- Location: LCCOMB_X11_Y1_N2
\blanking~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \blanking~1_combout\ = (\blanking~q\) # ((\Equal1~0_combout\ & (\Equal1~1_combout\ & \Equal1~3_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1110101010101010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \blanking~q\,
	datab => \Equal1~0_combout\,
	datac => \Equal1~1_combout\,
	datad => \Equal1~3_combout\,
	combout => \blanking~1_combout\);

-- Location: FF_X11_Y1_N5
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

-- Location: LCCOMB_X11_Y1_N6
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

-- Location: FF_X11_Y1_N7
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

-- Location: LCCOMB_X11_Y1_N8
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

-- Location: FF_X11_Y1_N9
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

-- Location: FF_X11_Y1_N11
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

-- Location: LCCOMB_X12_Y1_N12
\Equal1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Equal1~0_combout\ = (!refresh_counter(3) & (refresh_counter(0) & (refresh_counter(1) & !refresh_counter(2))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000001000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => refresh_counter(3),
	datab => refresh_counter(0),
	datac => refresh_counter(1),
	datad => refresh_counter(2),
	combout => \Equal1~0_combout\);

-- Location: LCCOMB_X12_Y1_N10
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

-- Location: FF_X12_Y1_N11
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

-- Location: LCCOMB_X12_Y1_N18
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

-- Location: FF_X12_Y1_N19
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

-- Location: LCCOMB_X12_Y1_N24
\digit_index[1]~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \digit_index[1]~0_combout\ = digit_index(1) $ (((digit_index(0) & \blanking~q\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011110011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datab => digit_index(0),
	datac => digit_index(1),
	datad => \blanking~q\,
	combout => \digit_index[1]~0_combout\);

-- Location: FF_X12_Y1_N25
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

-- Location: IOIBUF_X11_Y0_N29
\digits[7]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(7),
	o => \digits[7]~input_o\);

-- Location: IOIBUF_X16_Y0_N29
\digits[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(3),
	o => \digits[3]~input_o\);

-- Location: LCCOMB_X15_Y1_N18
\Mux0~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & (\digits[7]~input_o\)) # (!digit_index(0) & ((\digits[3]~input_o\)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111101000001100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[7]~input_o\,
	datab => \digits[3]~input_o\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \Mux0~0_combout\);

-- Location: LCCOMB_X15_Y1_N12
\Mux0~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux0~1_combout\ = (digit_index(1) & ((\Mux0~0_combout\ & (\digits[15]~input_o\)) # (!\Mux0~0_combout\ & ((\digits[11]~input_o\))))) # (!digit_index(1) & (((\Mux0~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010111111000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[15]~input_o\,
	datab => \digits[11]~input_o\,
	datac => digit_index(1),
	datad => \Mux0~0_combout\,
	combout => \Mux0~1_combout\);

-- Location: IOIBUF_X14_Y0_N8
\digits[12]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(12),
	o => \digits[12]~input_o\);

-- Location: IOIBUF_X19_Y0_N29
\digits[8]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(8),
	o => \digits[8]~input_o\);

-- Location: IOIBUF_X19_Y0_N22
\digits[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(0),
	o => \digits[0]~input_o\);

-- Location: IOIBUF_X16_Y0_N8
\digits[4]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(4),
	o => \digits[4]~input_o\);

-- Location: LCCOMB_X15_Y1_N2
\Mux3~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & ((\digits[4]~input_o\))) # (!digit_index(0) & (\digits[0]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111110000001010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[0]~input_o\,
	datab => \digits[4]~input_o\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \Mux3~0_combout\);

-- Location: LCCOMB_X15_Y1_N4
\Mux3~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux3~1_combout\ = (digit_index(1) & ((\Mux3~0_combout\ & (\digits[12]~input_o\)) # (!\Mux3~0_combout\ & ((\digits[8]~input_o\))))) # (!digit_index(1) & (((\Mux3~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1010111111000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[12]~input_o\,
	datab => \digits[8]~input_o\,
	datac => digit_index(1),
	datad => \Mux3~0_combout\,
	combout => \Mux3~1_combout\);

-- Location: IOIBUF_X16_Y0_N22
\digits[5]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(5),
	o => \digits[5]~input_o\);

-- Location: IOIBUF_X11_Y0_N22
\digits[13]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(13),
	o => \digits[13]~input_o\);

-- Location: IOIBUF_X19_Y0_N15
\digits[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(1),
	o => \digits[1]~input_o\);

-- Location: IOIBUF_X19_Y0_N1
\digits[9]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(9),
	o => \digits[9]~input_o\);

-- Location: LCCOMB_X15_Y1_N6
\Mux2~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~0_combout\ = (digit_index(1) & (((\digits[9]~input_o\) # (digit_index(0))))) # (!digit_index(1) & (\digits[1]~input_o\ & ((!digit_index(0)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000011001010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[1]~input_o\,
	datab => \digits[9]~input_o\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \Mux2~0_combout\);

-- Location: LCCOMB_X15_Y1_N8
\Mux2~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux2~1_combout\ = (digit_index(0) & ((\Mux2~0_combout\ & ((\digits[13]~input_o\))) # (!\Mux2~0_combout\ & (\digits[5]~input_o\)))) # (!digit_index(0) & (((\Mux2~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111010110001000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => digit_index(0),
	datab => \digits[5]~input_o\,
	datac => \digits[13]~input_o\,
	datad => \Mux2~0_combout\,
	combout => \Mux2~1_combout\);

-- Location: IOIBUF_X19_Y0_N8
\digits[10]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(10),
	o => \digits[10]~input_o\);

-- Location: IOIBUF_X16_Y0_N15
\digits[14]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(14),
	o => \digits[14]~input_o\);

-- Location: IOIBUF_X23_Y0_N15
\digits[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(2),
	o => \digits[2]~input_o\);

-- Location: IOIBUF_X7_Y0_N22
\digits[6]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_digits(6),
	o => \digits[6]~input_o\);

-- Location: LCCOMB_X15_Y1_N10
\Mux1~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~0_combout\ = (digit_index(1) & (((digit_index(0))))) # (!digit_index(1) & ((digit_index(0) & ((\digits[6]~input_o\))) # (!digit_index(0) & (\digits[2]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111110000001010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[2]~input_o\,
	datab => \digits[6]~input_o\,
	datac => digit_index(1),
	datad => digit_index(0),
	combout => \Mux1~0_combout\);

-- Location: LCCOMB_X15_Y1_N16
\Mux1~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux1~1_combout\ = (digit_index(1) & ((\Mux1~0_combout\ & ((\digits[14]~input_o\))) # (!\Mux1~0_combout\ & (\digits[10]~input_o\)))) # (!digit_index(1) & (((\Mux1~0_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100111110100000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \digits[10]~input_o\,
	datab => \digits[14]~input_o\,
	datac => digit_index(1),
	datad => \Mux1~0_combout\,
	combout => \Mux1~1_combout\);

-- Location: LCCOMB_X15_Y1_N24
\Mux11~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux11~0_combout\ = (\Mux0~1_combout\ & ((\Mux2~1_combout\ $ (!\Mux1~1_combout\)) # (!\Mux3~1_combout\))) # (!\Mux0~1_combout\ & ((\Mux2~1_combout\) # (\Mux3~1_combout\ $ (!\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111011001111011",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux11~0_combout\);

-- Location: FF_X15_Y1_N25
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

-- Location: LCCOMB_X15_Y1_N14
\Mux10~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux10~0_combout\ = (\Mux0~1_combout\ & ((\Mux3~1_combout\ & (!\Mux2~1_combout\)) # (!\Mux3~1_combout\ & ((!\Mux1~1_combout\))))) # (!\Mux0~1_combout\ & ((\Mux3~1_combout\ $ (!\Mux2~1_combout\)) # (!\Mux1~1_combout\)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0100100101111111",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux10~0_combout\);

-- Location: FF_X15_Y1_N15
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

-- Location: LCCOMB_X15_Y1_N28
\Mux9~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux9~0_combout\ = (\Mux0~1_combout\ & (((\Mux3~1_combout\ & !\Mux2~1_combout\)) # (!\Mux1~1_combout\))) # (!\Mux0~1_combout\ & ((\Mux3~1_combout\) # ((\Mux1~1_combout\) # (!\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0101110111101111",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux9~0_combout\);

-- Location: FF_X15_Y1_N29
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

-- Location: LCCOMB_X15_Y1_N26
\Mux8~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux8~0_combout\ = (\Mux2~1_combout\ & ((\Mux3~1_combout\ & ((!\Mux1~1_combout\))) # (!\Mux3~1_combout\ & ((\Mux1~1_combout\) # (!\Mux0~1_combout\))))) # (!\Mux2~1_combout\ & ((\Mux0~1_combout\) # (\Mux3~1_combout\ $ (!\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0011111011011011",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux8~0_combout\);

-- Location: FF_X15_Y1_N27
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

-- Location: LCCOMB_X15_Y1_N20
\Mux7~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux7~0_combout\ = (\Mux2~1_combout\ & ((\Mux0~1_combout\) # ((!\Mux3~1_combout\)))) # (!\Mux2~1_combout\ & ((\Mux1~1_combout\ & (\Mux0~1_combout\)) # (!\Mux1~1_combout\ & ((!\Mux3~1_combout\)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011101010110011",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux7~0_combout\);

-- Location: FF_X15_Y1_N21
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

-- Location: LCCOMB_X15_Y1_N30
\Mux6~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux6~0_combout\ = (\Mux3~1_combout\ & (\Mux0~1_combout\ $ (((!\Mux2~1_combout\ & \Mux1~1_combout\))))) # (!\Mux3~1_combout\ & ((\Mux0~1_combout\) # ((\Mux1~1_combout\) # (!\Mux2~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011011110101011",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux6~0_combout\);

-- Location: FF_X15_Y1_N31
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

-- Location: LCCOMB_X15_Y1_N0
\Mux5~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux5~0_combout\ = (\Mux3~1_combout\ & ((\Mux0~1_combout\) # (\Mux2~1_combout\ $ (\Mux1~1_combout\)))) # (!\Mux3~1_combout\ & ((\Mux2~1_combout\) # (\Mux0~1_combout\ $ (\Mux1~1_combout\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1011110111111010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \Mux0~1_combout\,
	datab => \Mux3~1_combout\,
	datac => \Mux2~1_combout\,
	datad => \Mux1~1_combout\,
	combout => \Mux5~0_combout\);

-- Location: FF_X15_Y1_N1
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

-- Location: IOIBUF_X9_Y0_N15
\dp_in[1]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(1),
	o => \dp_in[1]~input_o\);

-- Location: IOIBUF_X9_Y0_N22
\dp_in[3]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(3),
	o => \dp_in[3]~input_o\);

-- Location: IOIBUF_X11_Y0_N8
\dp_in[0]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(0),
	o => \dp_in[0]~input_o\);

-- Location: IOIBUF_X9_Y0_N29
\dp_in[2]~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_dp_in(2),
	o => \dp_in[2]~input_o\);

-- Location: LCCOMB_X12_Y1_N20
\Mux4~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~0_combout\ = (digit_index(0) & (((digit_index(1))))) # (!digit_index(0) & ((digit_index(1) & ((\dp_in[2]~input_o\))) # (!digit_index(1) & (\dp_in[0]~input_o\))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111110000100010",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \dp_in[0]~input_o\,
	datab => digit_index(0),
	datac => \dp_in[2]~input_o\,
	datad => digit_index(1),
	combout => \Mux4~0_combout\);

-- Location: LCCOMB_X9_Y1_N4
\Mux4~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \Mux4~1_combout\ = (\Mux4~0_combout\ & (((\dp_in[3]~input_o\) # (!digit_index(0))))) # (!\Mux4~0_combout\ & (\dp_in[1]~input_o\ & ((digit_index(0)))))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1100101011110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \dp_in[1]~input_o\,
	datab => \dp_in[3]~input_o\,
	datac => \Mux4~0_combout\,
	datad => digit_index(0),
	combout => \Mux4~1_combout\);

-- Location: FF_X9_Y1_N5
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

-- Location: LCCOMB_X12_Y1_N28
\dig_en_reg~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~0_combout\ = (!\blanking~q\ & (!digit_index(0) & !digit_index(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000000010001",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \blanking~q\,
	datab => digit_index(0),
	datad => digit_index(1),
	combout => \dig_en_reg~0_combout\);

-- Location: FF_X12_Y1_N29
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

-- Location: LCCOMB_X12_Y1_N30
\dig_en_reg~1\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~1_combout\ = (!\blanking~q\ & (digit_index(0) & !digit_index(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000000001000100",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \blanking~q\,
	datab => digit_index(0),
	datad => digit_index(1),
	combout => \dig_en_reg~1_combout\);

-- Location: FF_X12_Y1_N31
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

-- Location: LCCOMB_X12_Y1_N16
\dig_en_reg~2\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~2_combout\ = (!\blanking~q\ & (!digit_index(0) & digit_index(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0001000100000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \blanking~q\,
	datab => digit_index(0),
	datad => digit_index(1),
	combout => \dig_en_reg~2_combout\);

-- Location: FF_X12_Y1_N17
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

-- Location: LCCOMB_X12_Y1_N22
\dig_en_reg~3\ : cycloneiii_lcell_comb
-- Equation(s):
-- \dig_en_reg~3_combout\ = (!\blanking~q\ & (digit_index(0) & digit_index(1)))

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0100010000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	dataa => \blanking~q\,
	datab => digit_index(0),
	datad => digit_index(1),
	combout => \dig_en_reg~3_combout\);

-- Location: FF_X12_Y1_N23
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


