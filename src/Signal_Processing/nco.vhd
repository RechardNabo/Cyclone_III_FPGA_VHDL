-- ============================================================================
-- Project: FPGA-Optimized Numerically Controlled Oscillator (NCO)
--
-- Description:
-- This VHDL module implements a high-performance Numerically Controlled Oscillator (NCO),
-- optimized for FPGA synthesis. NCOs are fundamental components in digital communication
-- systems, software-defined radios (SDR), and frequency synthesis applications.
-- This design focuses on generating highly accurate and stable sinusoidal waveforms
-- (sine and cosine) with fine frequency resolution and fast frequency switching capabilities.
--
-- Learning Objectives:
-- 1. Understand the principles of direct digital synthesis (DDS) and NCO architecture.
-- 2. Learn how to implement a phase accumulator and a phase-to-amplitude converter.
-- 3. Explore techniques for optimizing sine/cosine generation using look-up tables (LUTs),
--    CORDIC algorithms, or polynomial approximations.
-- 4. Implement phase dithering and noise shaping for improved spurious-free dynamic range (SFDR).
-- 5. Develop control logic for frequency tuning word (FTW) updates and phase offset control.
-- 6. Gain experience in designing high-speed, pipelined arithmetic units for NCO operations.
--
-- Implementation Guidance:
-- 1. **Phase Accumulator**: Design a high-resolution phase accumulator (e.g., 32-bit or 48-bit)
--    that adds a frequency tuning word (FTW) to its current phase on each clock cycle.
--    The most significant bits (MSBs) of the accumulator represent the output phase.
-- 2. **Frequency Tuning Word (FTW)**: The FTW determines the output frequency. It is calculated
--    as: FTW = (Desired_Frequency * 2^Phase_Accumulator_Width) / Clock_Frequency.
-- 3. **Phase-to-Amplitude Conversion**: Convert the phase output from the accumulator into
--    sine and cosine amplitude values. Common methods include:
--    - **Look-Up Table (LUT)**: Store pre-computed sine/cosine values in a ROM (Block RAM).
--      Interpolation can be used to improve resolution and reduce LUT size.
--    - **CORDIC Algorithm**: An iterative algorithm that can generate sine/cosine values
--      without multipliers, suitable for resource-constrained designs.
--    - **Polynomial Approximation**: Use Taylor series or other polynomial functions to
--      approximate sine/cosine, requiring multipliers and adders.
-- 4. **Output Data Width**: Define the amplitude output width (e.g., 12-bit or 16-bit) to
--    meet the required signal-to-noise ratio (SNR).
-- 5. **Pipelining**: Introduce pipeline stages in the phase accumulator and phase-to-amplitude
--    converter to achieve high clock frequencies.
-- 6. **Control Interface**: Implement an interface (e.g., AXI-Lite, simple register interface)
--    to load the FTW and control other NCO parameters (e.g., phase offset, enable).
-- 7. **Testbench Development**: Create a testbench to verify the NCO's functionality,
--    frequency accuracy, phase continuity, and SFDR using spectral analysis (e.g., FFT).
--
-- ----------------------------------------------------------------------------
-- Architecture:
-- The NCO will typically consist of:
-- - Phase Accumulator: An adder and a register to accumulate the FTW.
-- - Phase Truncation/Dithering: Selects the relevant phase bits for amplitude conversion.
-- - Phase-to-Amplitude Converter: LUT, CORDIC, or polynomial approximation for sine/cosine.
-- - Output Registers: To hold the generated sine and cosine samples.
-- - Control Logic: For loading FTW and managing NCO operations.
--
-- Example NCO Equation:
-- Phase_Accumulator[n+1] = Phase_Accumulator[n] + FTW
-- Output_Phase = Phase_Accumulator[MSBs]
-- Sine_Output = sin(2 * pi * Output_Phase / 2^Output_Phase_Width)
-- Cosine_Output = cos(2 * pi * Output_Phase / 2^Output_Phase_Width)
--
-- This VHDL template provides a basic structure. The actual implementation will
-- depend on the chosen phase-to-amplitude conversion method, desired performance,
-- and resource constraints.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco is
    generic (
        PHASE_ACC_WIDTH : natural := 32; -- Width of the phase accumulator
        OUTPUT_AMP_WIDTH: natural := 16  -- Width of the output amplitude (sine/cosine)
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        ftw             : in  std_logic_vector(PHASE_ACC_WIDTH-1 downto 0); -- Frequency Tuning Word
        phase_offset    : in  std_logic_vector(PHASE_ACC_WIDTH-1 downto 0); -- Optional phase offset
        enable          : in  std_logic;
        o_sine          : out signed(OUTPUT_AMP_WIDTH-1 downto 0);
        o_cosine        : out signed(OUTPUT_AMP_WIDTH-1 downto 0)
    );
end entity nco;

architecture rtl of nco is

    signal phase_accumulator_reg : unsigned(PHASE_ACC_WIDTH-1 downto 0) := (others => '0');
    signal current_phase         : unsigned(PHASE_ACC_WIDTH-1 downto 0);

    -- For LUT-based approach, define a ROM for sine/cosine values
    -- type sine_rom_t is array (0 to 2**(PHASE_ACC_WIDTH - (PHASE_ACC_WIDTH - LOG2_LUT_SIZE))-1) of signed(OUTPUT_AMP_WIDTH-1 downto 0);
    -- constant SINE_ROM : sine_rom_t := (...);

    -- For CORDIC or polynomial, define internal signals for iterative calculations

begin

    -- Phase Accumulator Process
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase_accumulator_reg <= (others => '0');
            elsif enable = '1' then
                phase_accumulator_reg <= phase_accumulator_reg + unsigned(ftw);
            end if;
        end if;
    end process;

    -- Add phase offset (if required)
    current_phase <= phase_accumulator_reg + unsigned(phase_offset);

    -- Phase-to-Amplitude Converter (Placeholder)
    -- This section would implement the logic to convert 'current_phase' into
    -- sine and cosine amplitude values. This could be a LUT, CORDIC, or
    -- polynomial approximation.

    -- Example: Simple truncation for phase to index into a hypothetical LUT
    -- Assuming a LUT-based approach for demonstration
    -- constant LUT_ADDR_WIDTH : natural := 10; -- Example LUT address width
    -- signal lut_address : natural range 0 to 2**LUT_ADDR_WIDTH - 1;
    -- lut_address <= to_integer(current_phase(PHASE_ACC_WIDTH-1 downto PHASE_ACC_WIDTH-LUT_ADDR_WIDTH));

    -- For now, just outputting a placeholder (e.g., MSBs of phase accumulator)
    -- In a real NCO, this would be the result of sine/cosine generation.
    o_sine <= signed(current_phase(OUTPUT_AMP_WIDTH-1 downto 0)); -- Placeholder
    o_cosine <= signed(current_phase(OUTPUT_AMP_WIDTH-1 downto 0)); -- Placeholder

end architecture rtl;