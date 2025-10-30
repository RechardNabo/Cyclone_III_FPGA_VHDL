-- ============================================================================
-- Project: FPGA-Optimized CORDIC (Coordinate Rotation Digital Computer)
--
-- Description:
-- This VHDL module implements a high-performance CORDIC algorithm, optimized for FPGA
-- synthesis. CORDIC is an efficient iterative algorithm used for calculating trigonometric
-- functions (sine, cosine, arctangent), hyperbolic functions, multiplications, divisions,
-- and square roots, primarily using only additions, subtractions, and bit shifts.
-- This design focuses on achieving high accuracy and throughput with minimal hardware
-- resources, making it ideal for applications in digital signal processing, graphics,
-- and control systems where hardware multipliers are scarce or power consumption is critical.
--
-- Learning Objectives:
-- 1. Understand the fundamental principles of the CORDIC algorithm (rotation and vectoring modes).
-- 2. Learn how to implement the iterative CORDIC equations in synthesizable VHDL.
-- 3. Explore techniques for fixed-point arithmetic and scaling within the CORDIC iterations.
-- 4. Implement pipelining strategies to accelerate the CORDIC computation for higher throughput.
-- 5. Develop control logic for managing the iterative process and selecting CORDIC modes.
-- 6. Gain experience in designing a parameterizable CORDIC core for various precision
--    and function requirements.
--
-- Implementation Guidance:
-- 1. **CORDIC Modes**: Implement both rotation mode (for sine/cosine generation) and
--    vectoring mode (for magnitude/phase calculation).
-- 2. **Iterative Stages**: The CORDIC algorithm is iterative. Each iteration involves a
--    rotation angle (atan(2^-i)) and corresponding shifts and additions/subtractions.
--    The number of iterations determines the precision.
-- 3. **Fixed-Point Representation**: Define the data width and fractional bits for the
--    input angle, output coordinates (X, Y), and internal states to balance precision
--    and hardware cost. Use VHDL packages like 'fixed_pkg' if available.
-- 4. **Angle Table**: Pre-compute and store the `atan(2^-i)` values (or their fixed-point
--    equivalents) in a ROM or hardcode them as constants.
-- 5. **Scaling Factor**: The CORDIC algorithm introduces a gain (scaling factor) that needs
--    to be compensated, either by pre-scaling the input or post-scaling the output.
--    This can be done with a final multiplication or a series of shifts and adds.
-- 6. **Pipelining**: For high-speed applications, pipeline the iterative stages. This means
--    each stage of the CORDIC algorithm is implemented in a separate clock cycle.
-- 7. **Control Logic**: Design a state machine or combinatorial logic to control the
--    iterations, select the rotation direction, and manage data flow.
-- 8. **Testbench Development**: Create a comprehensive testbench to verify the CORDIC's
--    functionality, accuracy, and performance for various input angles and modes,
--    comparing against software-simulated results.
--
-- ----------------------------------------------------------------------------
-- Architecture:
-- A typical CORDIC architecture will consist of:
-- - Input registers for X, Y, and Z (angle) values.
-- - Iterative stages, each performing shifts and additions/subtractions.
-- - Angle lookup table (ROM) for `atan(2^-i)` values.
-- - Control logic for iteration management.
-- - Output registers for the final X, Y, and Z values.
-- - Optional: Scaling compensation logic.
--
-- Example CORDIC Iteration (Rotation Mode):
-- If Z_i >= 0: d_i = 1 (rotate clockwise)
-- Else: d_i = -1 (rotate counter-clockwise)
--
-- X_{i+1} = X_i - d_i * Y_i * 2^-i
-- Y_{i+1} = Y_i + d_i * X_i * 2^-i
-- Z_{i+1} = Z_i - d_i * atan(2^-i)
--
-- This VHDL template provides a basic structure. The actual implementation will
-- depend on the desired precision, throughput, and specific functions to be computed.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic is
    generic (
        DATA_WIDTH      : natural := 16; -- Width of X, Y, and Z (angle) data
        FRAC_BITS       : natural := 14; -- Number of fractional bits for fixed-point
        NUM_ITERATIONS  : natural := 16  -- Number of CORDIC iterations (determines precision)
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        enable          : in  std_logic;
        start           : in  std_logic; -- Start computation
        mode            : in  std_logic; -- '0' for rotation, '1' for vectoring
        i_x             : in  signed(DATA_WIDTH-1 downto 0);
        i_y             : in  signed(DATA_WIDTH-1 downto 0);
        i_z             : in  signed(DATA_WIDTH-1 downto 0); -- Input angle for rotation, 0 for vectoring
        o_x             : out signed(DATA_WIDTH-1 downto 0);
        o_y             : out signed(DATA_WIDTH-1 downto 0);
        o_z             : out signed(DATA_WIDTH-1 downto 0); -- Output angle for vectoring, 0 for rotation
        ready           : out std_logic; -- Indicates computation is complete
        valid           : out std_logic  -- Indicates output data is valid
    );
end entity cordic;

architecture rtl of cordic is

    -- Internal signals for CORDIC iterations
    type cordic_state_t is record
        x_val : signed(DATA_WIDTH-1 downto 0);
        y_val : signed(DATA_WIDTH-1 downto 0);
        z_val : signed(DATA_WIDTH-1 downto 0);
    end record;

    type cordic_pipeline_array_t is array (0 to NUM_ITERATIONS) of cordic_state_t;
    signal pipeline_stages : cordic_pipeline_array_t;

    -- Pre-computed CORDIC angles (atan(2^-i) in fixed-point)
    -- These values would be calculated based on FRAC_BITS and DATA_WIDTH
    -- For example, for FRAC_BITS = 14, atan(2^-0) = 0.785398 rad = 0.785398 * 2^14 = 12887 (approx)
    -- This is a placeholder and needs to be accurately generated.
    type angle_table_t is array (0 to NUM_ITERATIONS-1) of signed(DATA_WIDTH-1 downto 0);
    constant CORDIC_ANGLES : angle_table_t := (
        -- Example values (replace with actual fixed-point atan(2^-i) values)
        (others => '0')
    );

    signal current_iteration : natural range 0 to NUM_ITERATIONS;
    signal busy            : std_logic := '0';

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pipeline_stages(0).x_val <= (others => '0');
                pipeline_stages(0).y_val <= (others => '0');
                pipeline_stages(0).z_val <= (others => '0');
                current_iteration <= 0;
                busy <= '0';
                valid <= '0';
                ready <= '1';
            else
                valid <= '0';
                if start = '1' and ready = '1' then
                    -- Initialize first stage with input values
                    pipeline_stages(0).x_val <= i_x;
                    pipeline_stages(0).y_val <= i_y;
                    pipeline_stages(0).z_val <= i_z;
                    current_iteration <= 1;
                    busy <= '1';
                    ready <= '0';
                elsif busy = '1' then
                    -- Iterate through CORDIC stages
                    for i in 0 to NUM_ITERATIONS-1 loop
                        if current_iteration > i then
                            -- Determine rotation direction
                            variable d_i : signed(0 downto 0);
                            if mode = '0' then -- Rotation Mode
                                if pipeline_stages(i).z_val >= 0 then
                                    d_i := to_signed(1, 1);
                                else
                                    d_i := to_signed(-1, 1);
                                end if;
                            else -- Vectoring Mode
                                if pipeline_stages(i).y_val >= 0 then
                                    d_i := to_signed(-1, 1);
                                else
                                    d_i := to_signed(1, 1);
                                end if;
                            end if;

                            -- Perform CORDIC rotation
                            -- Note: Shifting by 'i' bits for 2^-i. Need to handle sign extension for shifts.
                            -- This is a simplified representation. Actual implementation needs careful fixed-point handling.
                            pipeline_stages(i+1).x_val <= pipeline_stages(i).x_val - d_i * (pipeline_stages(i).y_val sra i);
                            pipeline_stages(i+1).y_val <= pipeline_stages(i).y_val + d_i * (pipeline_stages(i).x_val sra i);

                            if mode = '0' then -- Rotation Mode
                                pipeline_stages(i+1).z_val <= pipeline_stages(i).z_val - d_i * CORDIC_ANGLES(i);
                            else -- Vectoring Mode
                                pipeline_stages(i+1).z_val <= pipeline_stages(i).z_val + d_i * CORDIC_ANGLES(i);
                            end if;
                        end if;
                    end loop;

                    if current_iteration = NUM_ITERATIONS then
                        -- Computation complete
                        o_x <= pipeline_stages(NUM_ITERATIONS).x_val;
                        o_y <= pipeline_stages(NUM_ITERATIONS).y_val;
                        o_z <= pipeline_stages(NUM_ITERATIONS).z_val;
                        valid <= '1';
                        busy <= '0';
                        ready <= '1';
                    else
                        current_iteration <= current_iteration + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;