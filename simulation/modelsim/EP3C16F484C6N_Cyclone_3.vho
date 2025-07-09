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

-- DATE "06/27/2025 21:51:48"

-- 
-- Device: Altera EP3C16F484C6 Package FBGA484
-- 

-- 
-- This VHDL file should be used for ModelSim-Altera (VHDL) only
-- 

LIBRARY CYCLONEIII;
LIBRARY IEEE;
USE CYCLONEIII.CYCLONEIII_COMPONENTS.ALL;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY 	Basic_Logic_Top IS
    PORT (
	A : IN std_logic;
	B : IN std_logic;
	and_out : OUT std_logic;
	or_out : OUT std_logic;
	nand_out : OUT std_logic;
	nor_out : OUT std_logic;
	xor_out : OUT std_logic;
	xnor_out : OUT std_logic;
	inv_out : OUT std_logic;
	driver_in : IN std_logic;
	driver_out : OUT std_logic
	);
END Basic_Logic_Top;

-- Design Ports Information
-- and_out	=>  Location: PIN_M1,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- or_out	=>  Location: PIN_W6,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- nand_out	=>  Location: PIN_J2,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- nor_out	=>  Location: PIN_N7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- xor_out	=>  Location: PIN_N2,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- xnor_out	=>  Location: PIN_M6,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- inv_out	=>  Location: PIN_E4,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- driver_out	=>  Location: PIN_J1,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- A	=>  Location: PIN_K7,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- B	=>  Location: PIN_V2,	 I/O Standard: 2.5 V,	 Current Strength: Default
-- driver_in	=>  Location: PIN_M2,	 I/O Standard: 2.5 V,	 Current Strength: Default


ARCHITECTURE structure OF Basic_Logic_Top IS
SIGNAL gnd : std_logic := '0';
SIGNAL vcc : std_logic := '1';
SIGNAL unknown : std_logic := 'X';
SIGNAL devoe : std_logic := '1';
SIGNAL devclrn : std_logic := '1';
SIGNAL devpor : std_logic := '1';
SIGNAL ww_devoe : std_logic;
SIGNAL ww_devclrn : std_logic;
SIGNAL ww_devpor : std_logic;
SIGNAL ww_A : std_logic;
SIGNAL ww_B : std_logic;
SIGNAL ww_and_out : std_logic;
SIGNAL ww_or_out : std_logic;
SIGNAL ww_nand_out : std_logic;
SIGNAL ww_nor_out : std_logic;
SIGNAL ww_xor_out : std_logic;
SIGNAL ww_xnor_out : std_logic;
SIGNAL ww_inv_out : std_logic;
SIGNAL ww_driver_in : std_logic;
SIGNAL ww_driver_out : std_logic;
SIGNAL \and_out~output_o\ : std_logic;
SIGNAL \or_out~output_o\ : std_logic;
SIGNAL \nand_out~output_o\ : std_logic;
SIGNAL \nor_out~output_o\ : std_logic;
SIGNAL \xor_out~output_o\ : std_logic;
SIGNAL \xnor_out~output_o\ : std_logic;
SIGNAL \inv_out~output_o\ : std_logic;
SIGNAL \driver_out~output_o\ : std_logic;
SIGNAL \B~input_o\ : std_logic;
SIGNAL \A~input_o\ : std_logic;
SIGNAL \AND_inst|f~combout\ : std_logic;
SIGNAL \OR_inst|f~combout\ : std_logic;
SIGNAL \XOR_inst|process_0~0_combout\ : std_logic;
SIGNAL \driver_in~input_o\ : std_logic;
SIGNAL \ALT_INV_A~input_o\ : std_logic;
SIGNAL \XOR_inst|ALT_INV_process_0~0_combout\ : std_logic;
SIGNAL \OR_inst|ALT_INV_f~combout\ : std_logic;
SIGNAL \AND_inst|ALT_INV_f~combout\ : std_logic;

BEGIN

ww_A <= A;
ww_B <= B;
and_out <= ww_and_out;
or_out <= ww_or_out;
nand_out <= ww_nand_out;
nor_out <= ww_nor_out;
xor_out <= ww_xor_out;
xnor_out <= ww_xnor_out;
inv_out <= ww_inv_out;
ww_driver_in <= driver_in;
driver_out <= ww_driver_out;
ww_devoe <= devoe;
ww_devclrn <= devclrn;
ww_devpor <= devpor;
\ALT_INV_A~input_o\ <= NOT \A~input_o\;
\XOR_inst|ALT_INV_process_0~0_combout\ <= NOT \XOR_inst|process_0~0_combout\;
\OR_inst|ALT_INV_f~combout\ <= NOT \OR_inst|f~combout\;
\AND_inst|ALT_INV_f~combout\ <= NOT \AND_inst|f~combout\;

-- Location: IOOBUF_X0_Y13_N23
\and_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \AND_inst|f~combout\,
	devoe => ww_devoe,
	o => \and_out~output_o\);

-- Location: IOOBUF_X7_Y0_N23
\or_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \OR_inst|f~combout\,
	devoe => ww_devoe,
	o => \or_out~output_o\);

-- Location: IOOBUF_X0_Y20_N2
\nand_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \AND_inst|ALT_INV_f~combout\,
	devoe => ww_devoe,
	o => \nand_out~output_o\);

-- Location: IOOBUF_X0_Y6_N23
\nor_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \OR_inst|ALT_INV_f~combout\,
	devoe => ww_devoe,
	o => \nor_out~output_o\);

-- Location: IOOBUF_X0_Y12_N16
\xor_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \XOR_inst|process_0~0_combout\,
	devoe => ww_devoe,
	o => \xor_out~output_o\);

-- Location: IOOBUF_X0_Y13_N9
\xnor_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \XOR_inst|ALT_INV_process_0~0_combout\,
	devoe => ww_devoe,
	o => \xnor_out~output_o\);

-- Location: IOOBUF_X0_Y26_N2
\inv_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \ALT_INV_A~input_o\,
	devoe => ww_devoe,
	o => \inv_out~output_o\);

-- Location: IOOBUF_X0_Y20_N9
\driver_out~output\ : cycloneiii_io_obuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	open_drain_output => "false")
-- pragma translate_on
PORT MAP (
	i => \driver_in~input_o\,
	devoe => ww_devoe,
	o => \driver_out~output_o\);

-- Location: IOIBUF_X0_Y9_N22
\B~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_B,
	o => \B~input_o\);

-- Location: IOIBUF_X0_Y22_N22
\A~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_A,
	o => \A~input_o\);

-- Location: LCCOMB_X1_Y8_N0
\AND_inst|f\ : cycloneiii_lcell_comb
-- Equation(s):
-- \AND_inst|f~combout\ = (\B~input_o\ & \A~input_o\)

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111000000000000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => \B~input_o\,
	datad => \A~input_o\,
	combout => \AND_inst|f~combout\);

-- Location: LCCOMB_X1_Y8_N2
\OR_inst|f\ : cycloneiii_lcell_comb
-- Equation(s):
-- \OR_inst|f~combout\ = (\B~input_o\) # (\A~input_o\)

-- pragma translate_off
GENERIC MAP (
	lut_mask => "1111111111110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => \B~input_o\,
	datad => \A~input_o\,
	combout => \OR_inst|f~combout\);

-- Location: LCCOMB_X1_Y8_N4
\XOR_inst|process_0~0\ : cycloneiii_lcell_comb
-- Equation(s):
-- \XOR_inst|process_0~0_combout\ = \B~input_o\ $ (\A~input_o\)

-- pragma translate_off
GENERIC MAP (
	lut_mask => "0000111111110000",
	sum_lutc_input => "datac")
-- pragma translate_on
PORT MAP (
	datac => \B~input_o\,
	datad => \A~input_o\,
	combout => \XOR_inst|process_0~0_combout\);

-- Location: IOIBUF_X0_Y13_N15
\driver_in~input\ : cycloneiii_io_ibuf
-- pragma translate_off
GENERIC MAP (
	bus_hold => "false",
	simulate_z_as => "z")
-- pragma translate_on
PORT MAP (
	i => ww_driver_in,
	o => \driver_in~input_o\);

ww_and_out <= \and_out~output_o\;

ww_or_out <= \or_out~output_o\;

ww_nand_out <= \nand_out~output_o\;

ww_nor_out <= \nor_out~output_o\;

ww_xor_out <= \xor_out~output_o\;

ww_xnor_out <= \xnor_out~output_o\;

ww_inv_out <= \inv_out~output_o\;

ww_driver_out <= \driver_out~output_o\;
END structure;


