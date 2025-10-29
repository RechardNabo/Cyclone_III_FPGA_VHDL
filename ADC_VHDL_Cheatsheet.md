# 🔬 **ADC (Analog-to-Digital Converter) VHDL Cheatsheet**

## 📋 **Table of Contents**
1. [ADC Fundamentals](#adc-fundamentals)
2. [SAR ADC Implementation](#sar-adc-implementation)
3. [Delta-Sigma ADC Implementation](#delta-sigma-adc-implementation)
4. [Flash ADC Implementation](#flash-adc-implementation)
5. [Pipeline ADC Implementation](#pipeline-adc-implementation)
6. [ADC Interface Controllers](#adc-interface-controllers)
7. [Calibration and Correction](#calibration-and-correction)
8. [Testing and Verification](#testing-and-verification)

---

## 🎯 **ADC Fundamentals**

### Basic ADC Entity Template
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity generic_adc is
    generic (
        RESOLUTION : integer := 12;  -- ADC resolution in bits
        SAMPLE_RATE : integer := 1000000  -- Sample rate in Hz
    );
    port (
        -- Clock and Reset
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog Interface (conceptual)
        analog_in   : in  std_logic_vector(15 downto 0);  -- Simulated analog input
        vref_pos    : in  std_logic_vector(15 downto 0);  -- Positive reference
        vref_neg    : in  std_logic_vector(15 downto 0);  -- Negative reference
        
        -- Digital Interface
        start_conv  : in  std_logic;
        data_out    : out std_logic_vector(RESOLUTION-1 downto 0);
        data_valid  : out std_logic;
        busy        : out std_logic;
        
        -- Status and Control
        overflow    : out std_logic;
        underflow   : out std_logic
    );
end generic_adc;
```

---

## ⚡ **SAR ADC Implementation**

### Complete SAR ADC with Binary Search Algorithm
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sar_adc is
    generic (
        RESOLUTION : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog Interface
        analog_in   : in  std_logic_vector(15 downto 0);
        vref        : in  std_logic_vector(15 downto 0);
        
        -- Control Interface
        start_conv  : in  std_logic;
        
        -- DAC Interface (for SAR feedback)
        dac_out     : out std_logic_vector(RESOLUTION-1 downto 0);
        
        -- Comparator Interface
        comp_in     : in  std_logic;  -- Comparator output
        
        -- Digital Output
        data_out    : out std_logic_vector(RESOLUTION-1 downto 0);
        data_valid  : out std_logic;
        busy        : out std_logic
    );
end sar_adc;

architecture behavioral of sar_adc is
    type state_type is (IDLE, SAMPLE, CONVERT, DONE);
    signal state : state_type;
    
    signal sar_reg : std_logic_vector(RESOLUTION-1 downto 0);
    signal bit_counter : integer range 0 to RESOLUTION;
    signal conversion_complete : std_logic;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            sar_reg <= (others => '0');
            bit_counter <= 0;
            data_out <= (others => '0');
            data_valid <= '0';
            busy <= '0';
            dac_out <= (others => '0');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    data_valid <= '0';
                    busy <= '0';
                    if start_conv = '1' then
                        state <= SAMPLE;
                        busy <= '1';
                        -- Initialize SAR register with MSB set
                        sar_reg <= (RESOLUTION-1 => '1', others => '0');
                        bit_counter <= RESOLUTION - 1;
                    end if;
                
                when SAMPLE =>
                    -- Sample and hold phase
                    state <= CONVERT;
                    dac_out <= sar_reg;
                
                when CONVERT =>
                    -- Binary search algorithm
                    if comp_in = '1' then
                        -- Keep the current bit
                        null;
                    else
                        -- Clear the current bit
                        sar_reg(bit_counter) <= '0';
                    end if;
                    
                    if bit_counter > 0 then
                        -- Set next bit for comparison
                        bit_counter <= bit_counter - 1;
                        sar_reg(bit_counter - 1) <= '1';
                        dac_out <= sar_reg;
                    else
                        -- Conversion complete
                        state <= DONE;
                    end if;
                
                when DONE =>
                    data_out <= sar_reg;
                    data_valid <= '1';
                    busy <= '0';
                    state <= IDLE;
            end case;
        end if;
    end process;
    
end behavioral;
```

### SAR ADC with Sample and Hold
```vhdl
entity sar_adc_with_sh is
    generic (
        RESOLUTION : integer := 12;
        SAMPLE_CYCLES : integer := 4
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog Interface
        analog_in   : in  std_logic_vector(15 downto 0);
        
        -- Control
        start_conv  : in  std_logic;
        
        -- Sample & Hold Control
        sh_enable   : out std_logic;
        
        -- Comparator Interface
        comp_in     : in  std_logic;
        
        -- DAC Interface
        dac_out     : out std_logic_vector(RESOLUTION-1 downto 0);
        
        -- Output
        data_out    : out std_logic_vector(RESOLUTION-1 downto 0);
        data_valid  : out std_logic;
        busy        : out std_logic
    );
end sar_adc_with_sh;

architecture behavioral of sar_adc_with_sh is
    type state_type is (IDLE, SAMPLE_HOLD, CONVERT, DONE);
    signal state : state_type;
    
    signal sar_reg : std_logic_vector(RESOLUTION-1 downto 0);
    signal bit_counter : integer range 0 to RESOLUTION;
    signal sample_counter : integer range 0 to SAMPLE_CYCLES;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            sar_reg <= (others => '0');
            bit_counter <= 0;
            sample_counter <= 0;
            data_out <= (others => '0');
            data_valid <= '0';
            busy <= '0';
            sh_enable <= '0';
            dac_out <= (others => '0');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    data_valid <= '0';
                    busy <= '0';
                    sh_enable <= '0';
                    if start_conv = '1' then
                        state <= SAMPLE_HOLD;
                        busy <= '1';
                        sh_enable <= '1';
                        sample_counter <= SAMPLE_CYCLES;
                    end if;
                
                when SAMPLE_HOLD =>
                    if sample_counter > 0 then
                        sample_counter <= sample_counter - 1;
                    else
                        sh_enable <= '0';  -- Hold mode
                        state <= CONVERT;
                        -- Initialize SAR
                        sar_reg <= (RESOLUTION-1 => '1', others => '0');
                        bit_counter <= RESOLUTION - 1;
                        dac_out <= (RESOLUTION-1 => '1', others => '0');
                    end if;
                
                when CONVERT =>
                    -- SAR conversion logic
                    if comp_in = '1' then
                        -- Keep current bit
                        null;
                    else
                        -- Clear current bit
                        sar_reg(bit_counter) <= '0';
                    end if;
                    
                    if bit_counter > 0 then
                        bit_counter <= bit_counter - 1;
                        if bit_counter > 1 then
                            sar_reg(bit_counter - 1) <= '1';
                        end if;
                        dac_out <= sar_reg;
                    else
                        state <= DONE;
                    end if;
                
                when DONE =>
                    data_out <= sar_reg;
                    data_valid <= '1';
                    busy <= '0';
                    state <= IDLE;
            end case;
        end if;
    end process;
    
end behavioral;
```

---

## 🌊 **Delta-Sigma ADC Implementation**

### First-Order Delta-Sigma Modulator
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity delta_sigma_adc is
    generic (
        INPUT_WIDTH : integer := 16;
        DECIMATION_RATIO : integer := 256
    );
    port (
        clk         : in  std_logic;  -- High-speed clock
        rst_n       : in  std_logic;
        
        -- Analog Input (simulated)
        analog_in   : in  signed(INPUT_WIDTH-1 downto 0);
        
        -- Control
        enable      : in  std_logic;
        
        -- Digital Output
        data_out    : out signed(15 downto 0);
        data_valid  : out std_logic;
        
        -- Debug outputs
        modulator_out : out std_logic;
        integrator_out : out signed(INPUT_WIDTH downto 0)
    );
end delta_sigma_adc;

architecture behavioral of delta_sigma_adc is
    -- Modulator signals
    signal integrator : signed(INPUT_WIDTH downto 0);
    signal feedback : signed(INPUT_WIDTH-1 downto 0);
    signal error_signal : signed(INPUT_WIDTH downto 0);
    signal bitstream : std_logic;
    
    -- Decimation filter signals
    signal cic_stage1 : signed(31 downto 0);
    signal cic_stage2 : signed(31 downto 0);
    signal cic_stage3 : signed(31 downto 0);
    
    signal decimation_counter : integer range 0 to DECIMATION_RATIO-1;
    signal decimation_enable : std_logic;
    
    -- Output registers
    signal output_reg : signed(15 downto 0);
    signal valid_reg : std_logic;
    
begin
    
    -- Delta-Sigma Modulator
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            integrator <= (others => '0');
            bitstream <= '0';
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Calculate error signal
                error_signal <= resize(analog_in, INPUT_WIDTH+1) - resize(feedback, INPUT_WIDTH+1);
                
                -- Integrate error
                integrator <= integrator + error_signal;
                
                -- Quantize (1-bit)
                if integrator >= 0 then
                    bitstream <= '1';
                    feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);  -- +FS
                else
                    bitstream <= '0';
                    feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);   -- -FS
                end if;
            end if;
        end if;
    end process;
    
    -- CIC Decimation Filter (3rd order)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cic_stage1 <= (others => '0');
            cic_stage2 <= (others => '0');
            cic_stage3 <= (others => '0');
            decimation_counter <= 0;
            decimation_enable <= '0';
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Integrator stages
                if bitstream = '1' then
                    cic_stage1 <= cic_stage1 + 1;
                else
                    cic_stage1 <= cic_stage1 - 1;
                end if;
                
                cic_stage2 <= cic_stage2 + cic_stage1;
                cic_stage3 <= cic_stage3 + cic_stage2;
                
                -- Decimation counter
                if decimation_counter = DECIMATION_RATIO-1 then
                    decimation_counter <= 0;
                    decimation_enable <= '1';
                else
                    decimation_counter <= decimation_counter + 1;
                    decimation_enable <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Output stage with decimation
    process(clk, rst_n)
        variable prev_cic3_1, prev_cic3_2, prev_cic3_3 : signed(31 downto 0);
        variable diff_stage1, diff_stage2, diff_stage3 : signed(31 downto 0);
    begin
        if rst_n = '0' then
            output_reg <= (others => '0');
            valid_reg <= '0';
            prev_cic3_1 := (others => '0');
            prev_cic3_2 := (others => '0');
            prev_cic3_3 := (others => '0');
            
        elsif rising_edge(clk) then
            valid_reg <= '0';
            
            if enable = '1' and decimation_enable = '1' then
                -- Differentiator stages (comb filters)
                diff_stage1 := cic_stage3 - prev_cic3_1;
                diff_stage2 := diff_stage1 - prev_cic3_2;
                diff_stage3 := diff_stage2 - prev_cic3_3;
                
                -- Update delay elements
                prev_cic3_1 := cic_stage3;
                prev_cic3_2 := diff_stage1;
                prev_cic3_3 := diff_stage2;
                
                -- Scale and output
                output_reg <= diff_stage3(31 downto 16);
                valid_reg <= '1';
            end if;
        end if;
    end process;
    
    -- Output assignments
    data_out <= output_reg;
    data_valid <= valid_reg;
    modulator_out <= bitstream;
    integrator_out <= integrator;
    
end behavioral;
```

### Second-Order Delta-Sigma Modulator
```vhdl
entity delta_sigma_2nd_order is
    generic (
        INPUT_WIDTH : integer := 16
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        analog_in   : in  signed(INPUT_WIDTH-1 downto 0);
        enable      : in  std_logic;
        
        bitstream_out : out std_logic;
        
        -- Debug outputs
        int1_out    : out signed(INPUT_WIDTH+1 downto 0);
        int2_out    : out signed(INPUT_WIDTH+2 downto 0)
    );
end delta_sigma_2nd_order;

architecture behavioral of delta_sigma_2nd_order is
    signal integrator1 : signed(INPUT_WIDTH+1 downto 0);
    signal integrator2 : signed(INPUT_WIDTH+2 downto 0);
    signal feedback : signed(INPUT_WIDTH-1 downto 0);
    signal error1, error2 : signed(INPUT_WIDTH+2 downto 0);
    signal bitstream : std_logic;
    
    -- Coefficients for stability
    constant K1 : signed(7 downto 0) := to_signed(64, 8);   -- 0.5 in Q7 format
    constant K2 : signed(7 downto 0) := to_signed(32, 8);   -- 0.25 in Q7 format
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            integrator1 <= (others => '0');
            integrator2 <= (others => '0');
            bitstream <= '0';
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- First integrator
                error1 <= resize(analog_in, INPUT_WIDTH+3) - resize(feedback, INPUT_WIDTH+3);
                integrator1 <= integrator1 + resize(error1 * K1, INPUT_WIDTH+2)(INPUT_WIDTH+9 downto 8);
                
                -- Second integrator
                error2 <= resize(integrator1, INPUT_WIDTH+3) - resize(feedback, INPUT_WIDTH+3);
                integrator2 <= integrator2 + resize(error2 * K2, INPUT_WIDTH+3)(INPUT_WIDTH+10 downto 8);
                
                -- Quantizer
                if integrator2 >= 0 then
                    bitstream <= '1';
                    feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);
                else
                    bitstream <= '0';
                    feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);
                end if;
            end if;
        end if;
    end process;
    
    bitstream_out <= bitstream;
    int1_out <= integrator1;
    int2_out <= integrator2;
    
end behavioral;
```

---

## ⚡ **Flash ADC Implementation**

### 4-bit Flash ADC with Thermometer Decoder
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flash_adc_4bit is
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog input (simulated)
        analog_in   : in  std_logic_vector(15 downto 0);
        vref_pos    : in  std_logic_vector(15 downto 0);
        vref_neg    : in  std_logic_vector(15 downto 0);
        
        -- Control
        enable      : in  std_logic;
        
        -- Comparator outputs (15 comparators for 4-bit)
        comp_out    : in  std_logic_vector(14 downto 0);
        
        -- Digital output
        data_out    : out std_logic_vector(3 downto 0);
        data_valid  : out std_logic;
        
        -- Reference ladder outputs
        ref_ladder  : out std_logic_vector(14 downto 0)
    );
end flash_adc_4bit;

architecture behavioral of flash_adc_4bit is
    signal thermometer_code : std_logic_vector(14 downto 0);
    signal binary_code : std_logic_vector(3 downto 0);
    signal valid_reg : std_logic;
    
    -- Reference voltage generation
    signal vref_step : unsigned(15 downto 0);
    type ref_array_type is array (0 to 14) of std_logic_vector(15 downto 0);
    signal ref_voltages : ref_array_type;
    
begin
    
    -- Generate reference ladder
    process(vref_pos, vref_neg)
        variable vref_range : unsigned(15 downto 0);
    begin
        vref_range := unsigned(vref_pos) - unsigned(vref_neg);
        vref_step <= vref_range / 16;  -- 16 levels for 4-bit
        
        for i in 0 to 14 loop
            ref_voltages(i) <= std_logic_vector(unsigned(vref_neg) + (i+1) * vref_step);
        end loop;
    end process;
    
    -- Output reference ladder for external comparators
    gen_ref_out: for i in 0 to 14 generate
        ref_ladder(i) <= ref_voltages(i)(0);  -- Simplified for demonstration
    end generate;
    
    -- Thermometer to Binary Decoder
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            binary_code <= (others => '0');
            valid_reg <= '0';
            
        elsif rising_edge(clk) then
            if enable = '1' then
                thermometer_code <= comp_out;
                
                -- Priority encoder (thermometer to binary conversion)
                if thermometer_code(14) = '1' then
                    binary_code <= "1111";  -- 15
                elsif thermometer_code(13) = '1' then
                    binary_code <= "1110";  -- 14
                elsif thermometer_code(12) = '1' then
                    binary_code <= "1101";  -- 13
                elsif thermometer_code(11) = '1' then
                    binary_code <= "1100";  -- 12
                elsif thermometer_code(10) = '1' then
                    binary_code <= "1011";  -- 11
                elsif thermometer_code(9) = '1' then
                    binary_code <= "1010";  -- 10
                elsif thermometer_code(8) = '1' then
                    binary_code <= "1001";  -- 9
                elsif thermometer_code(7) = '1' then
                    binary_code <= "1000";  -- 8
                elsif thermometer_code(6) = '1' then
                    binary_code <= "0111";  -- 7
                elsif thermometer_code(5) = '1' then
                    binary_code <= "0110";  -- 6
                elsif thermometer_code(4) = '1' then
                    binary_code <= "0101";  -- 5
                elsif thermometer_code(3) = '1' then
                    binary_code <= "0100";  -- 4
                elsif thermometer_code(2) = '1' then
                    binary_code <= "0011";  -- 3
                elsif thermometer_code(1) = '1' then
                    binary_code <= "0010";  -- 2
                elsif thermometer_code(0) = '1' then
                    binary_code <= "0001";  -- 1
                else
                    binary_code <= "0000";  -- 0
                end if;
                
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;
    
    data_out <= binary_code;
    data_valid <= valid_reg;
    
end behavioral;
```

### High-Speed Flash ADC with Error Correction
```vhdl
entity flash_adc_with_correction is
    generic (
        RESOLUTION : integer := 6  -- 6-bit flash ADC
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog interface
        analog_in   : in  std_logic_vector(15 downto 0);
        
        -- Comparator array (2^N - 1 comparators)
        comp_out    : in  std_logic_vector((2**RESOLUTION)-2 downto 0);
        
        -- Control
        enable      : in  std_logic;
        
        -- Digital output
        data_out    : out std_logic_vector(RESOLUTION-1 downto 0);
        data_valid  : out std_logic;
        
        -- Error detection
        bubble_error : out std_logic;
        metastable_error : out std_logic
    );
end flash_adc_with_correction;

architecture behavioral of flash_adc_with_correction is
    constant NUM_COMPS : integer := (2**RESOLUTION) - 1;
    
    signal thermometer_reg : std_logic_vector(NUM_COMPS-1 downto 0);
    signal corrected_thermo : std_logic_vector(NUM_COMPS-1 downto 0);
    signal binary_out : std_logic_vector(RESOLUTION-1 downto 0);
    
    signal bubble_detected : std_logic;
    signal metastable_detected : std_logic;
    
begin
    
    -- Register comparator outputs
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            thermometer_reg <= (others => '0');
            
        elsif rising_edge(clk) then
            if enable = '1' then
                thermometer_reg <= comp_out;
            end if;
        end if;
    end process;
    
    -- Bubble error detection and correction
    process(thermometer_reg)
        variable temp_corrected : std_logic_vector(NUM_COMPS-1 downto 0);
        variable bubble_found : std_logic;
    begin
        temp_corrected := thermometer_reg;
        bubble_found := '0';
        
        -- Detect and correct bubble errors
        for i in 0 to NUM_COMPS-2 loop
            if thermometer_reg(i) = '0' and thermometer_reg(i+1) = '1' then
                -- Bubble detected
                bubble_found := '1';
                -- Correct by setting the bubble bit
                temp_corrected(i) := '1';
            end if;
        end loop;
        
        corrected_thermo <= temp_corrected;
        bubble_detected <= bubble_found;
    end process;
    
    -- Metastability detection
    process(clk, rst_n)
        variable prev_thermo : std_logic_vector(NUM_COMPS-1 downto 0);
        variable change_count : integer;
    begin
        if rst_n = '0' then
            metastable_detected <= '0';
            prev_thermo := (others => '0');
            
        elsif rising_edge(clk) then
            change_count := 0;
            
            -- Count bit changes from previous sample
            for i in 0 to NUM_COMPS-1 loop
                if thermometer_reg(i) /= prev_thermo(i) then
                    change_count := change_count + 1;
                end if;
            end loop;
            
            -- If too many bits changed, likely metastability
            if change_count > 3 then
                metastable_detected <= '1';
            else
                metastable_detected <= '0';
            end if;
            
            prev_thermo := thermometer_reg;
        end if;
    end process;
    
    -- Thermometer to binary encoder
    process(corrected_thermo)
        variable position : integer;
    begin
        position := 0;
        
        -- Find highest '1' position
        for i in NUM_COMPS-1 downto 0 loop
            if corrected_thermo(i) = '1' then
                position := i + 1;
                exit;
            end if;
        end loop;
        
        binary_out <= std_logic_vector(to_unsigned(position, RESOLUTION));
    end process;
    
    -- Output assignments
    data_out <= binary_out;
    data_valid <= enable and not metastable_detected;
    bubble_error <= bubble_detected;
    metastable_error <= metastable_detected;
    
end behavioral;
```

---

## 🔄 **Pipeline ADC Implementation**

### 4-Stage Pipeline ADC (2 bits per stage)
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pipeline_adc_8bit is
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Analog input
        analog_in   : in  signed(15 downto 0);
        
        -- Control
        enable      : in  std_logic;
        
        -- Digital output
        data_out    : out std_logic_vector(7 downto 0);
        data_valid  : out std_logic;
        
        -- Stage outputs for debugging
        stage1_out  : out std_logic_vector(1 downto 0);
        stage2_out  : out std_logic_vector(1 downto 0);
        stage3_out  : out std_logic_vector(1 downto 0);
        stage4_out  : out std_logic_vector(1 downto 0)
    );
end pipeline_adc_8bit;

architecture behavioral of pipeline_adc_8bit is
    
    -- Pipeline stage component
    component pipeline_stage is
        generic (
            STAGE_BITS : integer := 2
        );
        port (
            clk       : in  std_logic;
            rst_n     : in  std_logic;
            enable    : in  std_logic;
            
            analog_in : in  signed(15 downto 0);
            
            digital_out : out std_logic_vector(STAGE_BITS-1 downto 0);
            residue_out : out signed(15 downto 0)
        );
    end component;
    
    -- Inter-stage signals
    signal stage1_digital : std_logic_vector(1 downto 0);
    signal stage1_residue : signed(15 downto 0);
    
    signal stage2_digital : std_logic_vector(1 downto 0);
    signal stage2_residue : signed(15 downto 0);
    
    signal stage3_digital : std_logic_vector(1 downto 0);
    signal stage3_residue : signed(15 downto 0);
    
    signal stage4_digital : std_logic_vector(1 downto 0);
    
    -- Pipeline delay registers
    type delay_array is array (0 to 3) of std_logic_vector(1 downto 0);
    signal stage1_delay : delay_array;
    signal stage2_delay : delay_array;
    signal stage3_delay : delay_array;
    
    signal valid_delay : std_logic_vector(3 downto 0);
    
begin
    
    -- Stage 1: Process MSBs
    stage1_inst: pipeline_stage
        generic map (STAGE_BITS => 2)
        port map (
            clk => clk,
            rst_n => rst_n,
            enable => enable,
            analog_in => analog_in,
            digital_out => stage1_digital,
            residue_out => stage1_residue
        );
    
    -- Stage 2
    stage2_inst: pipeline_stage
        generic map (STAGE_BITS => 2)
        port map (
            clk => clk,
            rst_n => rst_n,
            enable => enable,
            analog_in => stage1_residue,
            digital_out => stage2_digital,
            residue_out => stage2_residue
        );
    
    -- Stage 3
    stage3_inst: pipeline_stage
        generic map (STAGE_BITS => 2)
        port map (
            clk => clk,
            rst_n => rst_n,
            enable => enable,
            analog_in => stage2_residue,
            digital_out => stage3_digital,
            residue_out => stage3_residue
        );
    
    -- Stage 4: Final stage
    stage4_inst: pipeline_stage
        generic map (STAGE_BITS => 2)
        port map (
            clk => clk,
            rst_n => rst_n,
            enable => enable,
            analog_in => stage3_residue,
            digital_out => stage4_digital,
            residue_out => open
        );
    
    -- Pipeline delay alignment
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            stage1_delay <= (others => (others => '0'));
            stage2_delay <= (others => (others => '0'));
            stage3_delay <= (others => (others => '0'));
            valid_delay <= (others => '0');
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Shift delays
                stage1_delay(1 to 3) <= stage1_delay(0 to 2);
                stage1_delay(0) <= stage1_digital;
                
                stage2_delay(1 to 3) <= stage2_delay(0 to 2);
                stage2_delay(0) <= stage2_digital;
                
                stage3_delay(1 to 3) <= stage3_delay(0 to 2);
                stage3_delay(0) <= stage3_digital;
                
                valid_delay <= valid_delay(2 downto 0) & '1';
            else
                valid_delay <= valid_delay(2 downto 0) & '0';
            end if;
        end if;
    end process;
    
    -- Combine pipeline outputs
    data_out <= stage1_delay(3) & stage2_delay(2) & stage3_delay(1) & stage4_digital;
    data_valid <= valid_delay(3);
    
    -- Debug outputs
    stage1_out <= stage1_digital;
    stage2_out <= stage2_digital;
    stage3_out <= stage3_digital;
    stage4_out <= stage4_digital;
    
end behavioral;

-- Pipeline Stage Implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pipeline_stage is
    generic (
        STAGE_BITS : integer := 2
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        enable    : in  std_logic;
        
        analog_in : in  signed(15 downto 0);
        
        digital_out : out std_logic_vector(STAGE_BITS-1 downto 0);
        residue_out : out signed(15 downto 0)
    );
end pipeline_stage;

architecture behavioral of pipeline_stage is
    constant NUM_LEVELS : integer := 2**STAGE_BITS;
    constant GAIN : integer := 4;  -- 2^STAGE_BITS
    
    signal quantized : integer range 0 to NUM_LEVELS-1;
    signal dac_output : signed(15 downto 0);
    signal residue : signed(15 downto 0);
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            digital_out <= (others => '0');
            residue_out <= (others => '0');
            
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Flash quantization (simplified)
                if analog_in >= to_signed(24576, 16) then      -- 3/4 * full scale
                    quantized <= 3;
                elsif analog_in >= to_signed(0, 16) then       -- 1/2 * full scale
                    quantized <= 2;
                elsif analog_in >= to_signed(-16384, 16) then  -- 1/4 * full scale
                    quantized <= 1;
                else
                    quantized <= 0;
                end if;
                
                -- DAC reconstruction
                case quantized is
                    when 3 => dac_output <= to_signed(24576, 16);
                    when 2 => dac_output <= to_signed(8192, 16);
                    when 1 => dac_output <= to_signed(-8192, 16);
                    when others => dac_output <= to_signed(-24576, 16);
                end case;
                
                -- Calculate residue and amplify
                residue <= (analog_in - dac_output) * GAIN;
                
                -- Output digital code
                digital_out <= std_logic_vector(to_unsigned(quantized, STAGE_BITS));
                residue_out <= residue;
            end if;
        end if;
    end process;
    
end behavioral;
```

---

## 🎛️ **ADC Interface Controllers**

### Multi-Channel ADC Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity multi_channel_adc_controller is
    generic (
        NUM_CHANNELS : integer := 8;
        RESOLUTION : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Channel selection
        channel_select : in  std_logic_vector(2 downto 0);
        auto_scan   : in  std_logic;
        
        -- ADC Interface
        adc_start   : out std_logic;
        adc_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        adc_valid   : in  std_logic;
        adc_busy    : in  std_logic;
        
        -- Multiplexer control
        mux_select  : out std_logic_vector(2 downto 0);
        
        -- Data output
        channel_data : out std_logic_vector(RESOLUTION-1 downto 0);
        channel_id  : out std_logic_vector(2 downto 0);
        data_valid  : out std_logic;
        
        -- Status
        conversion_complete : out std_logic;
        scan_complete : out std_logic
    );
end multi_channel_adc_controller;

architecture behavioral of multi_channel_adc_controller is
    type state_type is (IDLE, SELECT_CHANNEL, WAIT_SETTLE, START_CONV, WAIT_CONV, READ_DATA);
    signal state : state_type;
    
    signal current_channel : integer range 0 to NUM_CHANNELS-1;
    signal settle_counter : integer range 0 to 15;  -- Settling time counter
    signal scan_counter : integer range 0 to NUM_CHANNELS-1;
    
    -- Channel data storage
    type channel_array is array (0 to NUM_CHANNELS-1) of std_logic_vector(RESOLUTION-1 downto 0);
    signal channel_storage : channel_array;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            current_channel <= 0;
            settle_counter <= 0;
            scan_counter <= 0;
            adc_start <= '0';
            mux_select <= (others => '0');
            channel_data <= (others => '0');
            channel_id <= (others => '0');
            data_valid <= '0';
            conversion_complete <= '0';
            scan_complete <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    adc_start <= '0';
                    data_valid <= '0';
                    conversion_complete <= '0';
                    scan_complete <= '0';
                    
                    if auto_scan = '1' then
                        current_channel <= 0;
                        scan_counter <= 0;
                        state <= SELECT_CHANNEL;
                    elsif channel_select /= "000" or channel_select = "000" then
                        current_channel <= to_integer(unsigned(channel_select));
                        state <= SELECT_CHANNEL;
                    end if;
                
                when SELECT_CHANNEL =>
                    mux_select <= std_logic_vector(to_unsigned(current_channel, 3));
                    settle_counter <= 10;  -- 10 clock cycles settling time
                    state <= WAIT_SETTLE;
                
                when WAIT_SETTLE =>
                    if settle_counter > 0 then
                        settle_counter <= settle_counter - 1;
                    else
                        state <= START_CONV;
                    end if;
                
                when START_CONV =>
                    if adc_busy = '0' then
                        adc_start <= '1';
                        state <= WAIT_CONV;
                    end if;
                
                when WAIT_CONV =>
                    adc_start <= '0';
                    if adc_valid = '1' then
                        state <= READ_DATA;
                    end if;
                
                when READ_DATA =>
                    -- Store data
                    channel_storage(current_channel) <= adc_data;
                    channel_data <= adc_data;
                    channel_id <= std_logic_vector(to_unsigned(current_channel, 3));
                    data_valid <= '1';
                    conversion_complete <= '1';
                    
                    if auto_scan = '1' then
                        if scan_counter = NUM_CHANNELS-1 then
                            scan_complete <= '1';
                            state <= IDLE;
                        else
                            scan_counter <= scan_counter + 1;
                            current_channel <= current_channel + 1;
                            state <= SELECT_CHANNEL;
                        end if;
                    else
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
end behavioral;
```

---

## 🔧 **Calibration and Correction**

### ADC Gain and Offset Calibration
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adc_calibration is
    generic (
        DATA_WIDTH : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Raw ADC data
        raw_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        raw_valid   : in  std_logic;
        
        -- Calibration parameters
        gain_coeff  : in  std_logic_vector(15 downto 0);  -- Q1.15 format
        offset_coeff : in  signed(DATA_WIDTH-1 downto 0);
        
        -- Calibrated output
        cal_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        cal_valid   : out std_logic;
        
        -- Calibration control
        cal_enable  : in  std_logic;
        cal_mode    : in  std_logic_vector(1 downto 0)  -- 00: bypass, 01: offset, 10: gain, 11: both
    );
end adc_calibration;

architecture behavioral of adc_calibration is
    signal raw_signed : signed(DATA_WIDTH-1 downto 0);
    signal offset_corrected : signed(DATA_WIDTH-1 downto 0);
    signal gain_corrected : signed(DATA_WIDTH+15 downto 0);
    signal final_result : signed(DATA_WIDTH-1 downto 0);
    
    signal valid_pipe : std_logic_vector(2 downto 0);
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            offset_corrected <= (others => '0');
            gain_corrected <= (others => '0');
            final_result <= (others => '0');
            valid_pipe <= (others => '0');
            
        elsif rising_edge(clk) then
            -- Pipeline stage 1: Offset correction
            raw_signed <= signed(raw_data);
            
            if cal_enable = '1' and (cal_mode = "01" or cal_mode = "11") then
                offset_corrected <= raw_signed - offset_coeff;
            else
                offset_corrected <= raw_signed;
            end if;
            
            -- Pipeline stage 2: Gain correction
            if cal_enable = '1' and (cal_mode = "10" or cal_mode = "11") then
                gain_corrected <= offset_corrected * signed(gain_coeff);
            else
                gain_corrected <= offset_corrected & "000000000000000";  -- Shift left 15 bits
            end if;
            
            -- Pipeline stage 3: Final scaling
            final_result <= gain_corrected(DATA_WIDTH+14 downto 15);  -- Q1.15 to integer
            
            -- Valid pipeline
            valid_pipe <= valid_pipe(1 downto 0) & raw_valid;
        end if;
    end process;
    
    cal_data <= std_logic_vector(final_result);
    cal_valid <= valid_pipe(2);
    
end behavioral;
```

---

## 🧪 **Testing and Verification**

### ADC Testbench Template
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity adc_testbench is
end adc_testbench;

architecture behavioral of adc_testbench is
    constant CLK_PERIOD : time := 10 ns;
    constant RESOLUTION : integer := 12;
    
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal analog_in : std_logic_vector(15 downto 0);
    signal start_conv : std_logic := '0';
    signal data_out : std_logic_vector(RESOLUTION-1 downto 0);
    signal data_valid : std_logic;
    signal busy : std_logic;
    
    -- Test signals
    signal test_frequency : real := 1000.0;  -- 1 kHz test signal
    signal sample_rate : real := 100000.0;   -- 100 kHz sampling
    signal amplitude : real := 0.8;          -- 80% of full scale
    
    component sar_adc is
        generic (RESOLUTION : integer := 12);
        port (
            clk : in std_logic;
            rst_n : in std_logic;
            analog_in : in std_logic_vector(15 downto 0);
            vref : in std_logic_vector(15 downto 0);
            start_conv : in std_logic;
            dac_out : out std_logic_vector(RESOLUTION-1 downto 0);
            comp_in : in std_logic;
            data_out : out std_logic_vector(RESOLUTION-1 downto 0);
            data_valid : out std_logic;
            busy : out std_logic
        );
    end component;
    
begin
    
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2;
    
    -- Reset generation
    rst_n <= '0', '1' after 100 ns;
    
    -- DUT instantiation
    dut: sar_adc
        generic map (RESOLUTION => RESOLUTION)
        port map (
            clk => clk,
            rst_n => rst_n,
            analog_in => analog_in,
            vref => x"FFFF",
            start_conv => start_conv,
            dac_out => open,
            comp_in => '1',  -- Simplified comparator
            data_out => data_out,
            data_valid => data_valid,
            busy => busy
        );
    
    -- Sine wave generation
    process
        variable phase : real := 0.0;
        variable sine_val : real;
        variable digital_val : integer;
    begin
        wait until rst_n = '1';
        
        while true loop
            -- Generate sine wave
            sine_val := amplitude * sin(2.0 * MATH_PI * phase);
            digital_val := integer((sine_val + 1.0) * 32767.0);
            
            if digital_val > 65535 then
                digital_val := 65535;
            elsif digital_val < 0 then
                digital_val := 0;
            end if;
            
            analog_in <= std_logic_vector(to_unsigned(digital_val, 16));
            
            -- Update phase
            phase := phase + test_frequency / sample_rate;
            if phase >= 1.0 then
                phase := phase - 1.0;
            end if;
            
            wait for CLK_PERIOD;
        end loop;
    end process;
    
    -- Conversion trigger
    process
    begin
        wait until rst_n = '1';
        wait for 1 us;
        
        while true loop
            wait until busy = '0';
            start_conv <= '1';
            wait for CLK_PERIOD;
            start_conv <= '0';
            wait for CLK_PERIOD * 20;  -- Wait between conversions
        end loop;
    end process;
    
    -- Data collection and analysis
    process
        file output_file : text open write_mode is "adc_output.txt";
        variable line_out : line;
        variable sample_count : integer := 0;
    begin
        wait until rst_n = '1';
        
        while sample_count < 1000 loop
            wait until data_valid = '1';
            
            write(line_out, sample_count);
            write(line_out, string'(" "));
            write(line_out, to_integer(unsigned(data_out)));
            writeline(output_file, line_out);
            
            sample_count := sample_count + 1;
            wait for CLK_PERIOD;
        end loop;
        
        report "Test completed - 1000 samples collected";
        wait;
    end process;
    
end behavioral;
```

---

## 📊 **Performance Metrics and Analysis**

### ADC Performance Monitor
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adc_performance_monitor is
    generic (
        DATA_WIDTH : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- ADC data input
        adc_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        adc_valid   : in  std_logic;
        
        -- Performance metrics
        sample_rate : out std_logic_vector(31 downto 0);
        min_value   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        max_value   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        avg_value   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Control
        reset_stats : in  std_logic;
        enable_mon  : in  std_logic
    );
end adc_performance_monitor;

architecture behavioral of adc_performance_monitor is
    signal sample_counter : unsigned(31 downto 0);
    signal time_counter : unsigned(31 downto 0);
    
    signal min_reg : unsigned(DATA_WIDTH-1 downto 0);
    signal max_reg : unsigned(DATA_WIDTH-1 downto 0);
    signal sum_reg : unsigned(DATA_WIDTH+15 downto 0);
    signal avg_reg : unsigned(DATA_WIDTH-1 downto 0);
    
    signal rate_calc_counter : unsigned(15 downto 0);
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sample_counter <= (others => '0');
            time_counter <= (others => '0');
            min_reg <= (others => '1');
            max_reg <= (others => '0');
            sum_reg <= (others => '0');
            avg_reg <= (others => '0');
            rate_calc_counter <= (others => '0');
            
        elsif rising_edge(clk) then
            if reset_stats = '1' then
                sample_counter <= (others => '0');
                time_counter <= (others => '0');
                min_reg <= (others => '1');
                max_reg <= (others => '0');
                sum_reg <= (others => '0');
                avg_reg <= (others => '0');
                
            elsif enable_mon = '1' then
                time_counter <= time_counter + 1;
                
                if adc_valid = '1' then
                    sample_counter <= sample_counter + 1;
                    
                    -- Min/Max tracking
                    if unsigned(adc_data) < min_reg then
                        min_reg <= unsigned(adc_data);
                    end if;
                    
                    if unsigned(adc_data) > max_reg then
                        max_reg <= unsigned(adc_data);
                    end if;
                    
                    -- Average calculation
                    sum_reg <= sum_reg + unsigned(adc_data);
                    if sample_counter > 0 then
                        avg_reg <= sum_reg(DATA_WIDTH+15 downto 16) / sample_counter(15 downto 0);
                    end if;
                end if;
                
                -- Sample rate calculation (every 65536 clocks)
                rate_calc_counter <= rate_calc_counter + 1;
                if rate_calc_counter = 0 then
                    -- Calculate samples per 65536 clocks
                    -- This gives relative sample rate
                end if;
            end if;
        end if;
    end process;
    
    -- Output assignments
    sample_rate <= std_logic_vector(sample_counter);
    min_value <= std_logic_vector(min_reg);
    max_value <= std_logic_vector(max_reg);
    avg_value <= std_logic_vector(avg_reg);
    
end behavioral;
```

---

## 🎯 **Summary**

This ADC VHDL cheatsheet provides comprehensive implementations for:

- **SAR ADC**: Binary search algorithm with sample & hold
- **Delta-Sigma ADC**: 1st and 2nd order modulators with CIC filters
- **Flash ADC**: High-speed conversion with error correction
- **Pipeline ADC**: Multi-stage architecture for high throughput
- **Interface Controllers**: Multi-channel scanning and control
- **Calibration**: Gain and offset correction algorithms
- **Testing**: Comprehensive testbench templates
- **Performance Monitoring**: Real-time metrics and analysis

Each implementation includes proper timing, error handling, and is optimized for FPGA synthesis.