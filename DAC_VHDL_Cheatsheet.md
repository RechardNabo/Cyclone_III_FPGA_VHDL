# 🎵 **DAC (Digital-to-Analog Converter) VHDL Cheatsheet**

## 📋 **Table of Contents**
1. [DAC Fundamentals](#dac-fundamentals)
2. [R-2R Ladder DAC Implementation](#r-2r-ladder-dac-implementation)
3. [PWM DAC Implementation](#pwm-dac-implementation)
4. [Delta-Sigma DAC Implementation](#delta-sigma-dac-implementation)
5. [Current Steering DAC Implementation](#current-steering-dac-implementation)
6. [String DAC Implementation](#string-dac-implementation)
7. [DAC Interface Controllers](#dac-interface-controllers)
8. [Calibration and Correction](#calibration-and-correction)
9. [Testing and Verification](#testing-and-verification)

---

## 🎯 **DAC Fundamentals**

### Basic DAC Entity Template
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity generic_dac is
    generic (
        RESOLUTION : integer := 12;  -- DAC resolution in bits
        UPDATE_RATE : integer := 1000000  -- Update rate in Hz
    );
    port (
        -- Clock and Reset
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital Interface
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        data_valid  : in  std_logic;
        load_data   : in  std_logic;
        
        -- Analog Interface (conceptual)
        analog_out  : out std_logic_vector(15 downto 0);  -- Simulated analog output
        vref_pos    : in  std_logic_vector(15 downto 0);  -- Positive reference
        vref_neg    : in  std_logic_vector(15 downto 0);  -- Negative reference
        
        -- Control and Status
        dac_enable  : in  std_logic;
        ready       : out std_logic;
        
        -- Power management
        power_down  : in  std_logic;
        sleep_mode  : in  std_logic
    );
end generic_dac;
```

---

## 🔗 **R-2R Ladder DAC Implementation**

### Complete R-2R DAC with Switch Control
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity r2r_dac is
    generic (
        RESOLUTION : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        load_data   : in  std_logic;
        
        -- Reference voltages
        vref_high   : in  std_logic_vector(15 downto 0);
        vref_low    : in  std_logic_vector(15 downto 0);
        
        -- R-2R ladder control
        switch_ctrl : out std_logic_vector(RESOLUTION-1 downto 0);
        
        -- Analog output (calculated)
        analog_out  : out std_logic_vector(15 downto 0);
        
        -- Status
        ready       : out std_logic;
        dac_enable  : in  std_logic
    );
end r2r_dac;

architecture behavioral of r2r_dac is
    signal data_reg : std_logic_vector(RESOLUTION-1 downto 0);
    signal output_calc : unsigned(31 downto 0);
    signal vref_range : unsigned(15 downto 0);
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            ready <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                if load_data = '1' then
                    data_reg <= data_in;
                end if;
                ready <= '1';
            else
                ready <= '0';
            end if;
        end if;
    end process;
    
    -- Switch control (direct mapping)
    switch_ctrl <= data_reg when dac_enable = '1' else (others => '0');
    
    -- Analog output calculation
    process(data_reg, vref_high, vref_low, dac_enable)
    begin
        if dac_enable = '1' then
            vref_range <= unsigned(vref_high) - unsigned(vref_low);
            
            -- Calculate output voltage: Vout = Vref_low + (data/2^N) * (Vref_high - Vref_low)
            output_calc <= unsigned(data_reg) * vref_range;
            analog_out <= std_logic_vector(unsigned(vref_low) + output_calc(RESOLUTION+15 downto RESOLUTION));
        else
            analog_out <= vref_low;  -- Output low when disabled
        end if;
    end process;
    
end behavioral;
```

### R-2R DAC with Glitch Reduction
```vhdl
entity r2r_dac_glitch_free is
    generic (
        RESOLUTION : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- R-2R ladder control with timing
        switch_ctrl : out std_logic_vector(RESOLUTION-1 downto 0);
        switch_enable : out std_logic;
        
        -- Analog output
        analog_out  : out std_logic_vector(15 downto 0);
        
        -- Status
        ready       : out std_logic;
        updating    : out std_logic
    );
end r2r_dac_glitch_free;

architecture behavioral of r2r_dac_glitch_free is
    type state_type is (IDLE, LOAD_MSB, LOAD_BITS, ENABLE_OUTPUT);
    signal state : state_type;
    
    signal data_reg : std_logic_vector(RESOLUTION-1 downto 0);
    signal temp_switches : std_logic_vector(RESOLUTION-1 downto 0);
    signal bit_counter : integer range 0 to RESOLUTION;
    signal update_delay : integer range 0 to 7;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            data_reg <= (others => '0');
            temp_switches <= (others => '0');
            bit_counter <= 0;
            update_delay <= 0;
            switch_enable <= '0';
            ready <= '0';
            updating <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    ready <= '1';
                    updating <= '0';
                    switch_enable <= '1';
                    
                    if load_data = '1' and dac_enable = '1' then
                        data_reg <= data_in;
                        state <= LOAD_MSB;
                        ready <= '0';
                        updating <= '1';
                        switch_enable <= '0';  -- Disable during update
                    end if;
                
                when LOAD_MSB =>
                    -- Start with MSB to minimize glitches
                    temp_switches <= (others => '0');
                    temp_switches(RESOLUTION-1) <= data_reg(RESOLUTION-1);
                    bit_counter <= RESOLUTION - 2;
                    update_delay <= 3;  -- Settling time
                    state <= LOAD_BITS;
                
                when LOAD_BITS =>
                    if update_delay > 0 then
                        update_delay <= update_delay - 1;
                    else
                        if bit_counter >= 0 then
                            temp_switches(bit_counter) <= data_reg(bit_counter);
                            bit_counter <= bit_counter - 1;
                            update_delay <= 1;  -- Small delay between bits
                        else
                            state <= ENABLE_OUTPUT;
                            update_delay <= 5;  -- Final settling time
                        end if;
                    end if;
                
                when ENABLE_OUTPUT =>
                    if update_delay > 0 then
                        update_delay <= update_delay - 1;
                    else
                        switch_enable <= '1';
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    -- Output switch control
    switch_ctrl <= temp_switches when switch_enable = '1' else (others => '0');
    
    -- Analog output calculation (simplified)
    process(temp_switches, switch_enable)
        variable output_val : unsigned(31 downto 0);
    begin
        if switch_enable = '1' then
            output_val := (others => '0');
            for i in 0 to RESOLUTION-1 loop
                if temp_switches(i) = '1' then
                    output_val := output_val + (2**(16+i-RESOLUTION));
                end if;
            end loop;
            analog_out <= std_logic_vector(output_val(15 downto 0));
        else
            analog_out <= (others => '0');
        end if;
    end process;
    
end behavioral;
```

---

## 🔄 **PWM DAC Implementation**

### High-Resolution PWM DAC
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pwm_dac is
    generic (
        RESOLUTION : integer := 12;
        PWM_FREQ : integer := 100000  -- 100 kHz PWM frequency
    );
    port (
        clk         : in  std_logic;  -- High-speed clock
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- PWM output
        pwm_out     : out std_logic;
        
        -- Low-pass filter control (external)
        lpf_enable  : out std_logic;
        
        -- Status
        ready       : out std_logic
    );
end pwm_dac;

architecture behavioral of pwm_dac is
    constant PWM_MAX : integer := 2**RESOLUTION - 1;
    constant CLK_FREQ : integer := 100000000;  -- 100 MHz
    constant PWM_PERIOD : integer := CLK_FREQ / PWM_FREQ;
    constant PWM_RESOLUTION : integer := PWM_PERIOD / (2**RESOLUTION);
    
    signal data_reg : unsigned(RESOLUTION-1 downto 0);
    signal pwm_counter : unsigned(RESOLUTION-1 downto 0);
    signal period_counter : integer range 0 to PWM_PERIOD-1;
    signal pwm_threshold : unsigned(RESOLUTION-1 downto 0);
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            pwm_counter <= (others => '0');
            period_counter <= 0;
            pwm_threshold <= (others => '0');
            pwm_out <= '0';
            ready <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                -- Load new data
                if load_data = '1' then
                    data_reg <= unsigned(data_in);
                    pwm_threshold <= unsigned(data_in);
                end if;
                
                -- PWM generation
                if period_counter = PWM_PERIOD-1 then
                    period_counter <= 0;
                    pwm_counter <= (others => '0');
                else
                    period_counter <= period_counter + 1;
                    
                    if period_counter mod PWM_RESOLUTION = 0 then
                        pwm_counter <= pwm_counter + 1;
                    end if;
                end if;
                
                -- PWM output generation
                if pwm_counter < pwm_threshold then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
                
                ready <= '1';
                lpf_enable <= '1';
            else
                pwm_out <= '0';
                ready <= '0';
                lpf_enable <= '0';
            end if;
        end if;
    end process;
    
end behavioral;
```

### Delta-Sigma PWM DAC
```vhdl
entity delta_sigma_pwm_dac is
    generic (
        INPUT_WIDTH : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- 1-bit output
        ds_out      : out std_logic;
        
        -- Status
        ready       : out std_logic;
        
        -- Debug
        error_out   : out signed(INPUT_WIDTH+1 downto 0);
        integrator_out : out signed(INPUT_WIDTH+1 downto 0)
    );
end delta_sigma_pwm_dac;

architecture behavioral of delta_sigma_pwm_dac is
    signal data_reg : signed(INPUT_WIDTH-1 downto 0);
    signal integrator : signed(INPUT_WIDTH+1 downto 0);
    signal error_signal : signed(INPUT_WIDTH+1 downto 0);
    signal feedback : signed(INPUT_WIDTH-1 downto 0);
    signal ds_output : std_logic;
    
begin
    
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            integrator <= (others => '0');
            ds_output <= '0';
            ready <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                -- Load new data
                if load_data = '1' then
                    data_reg <= signed(data_in);
                end if;
                
                -- Delta-Sigma modulation
                error_signal <= resize(data_reg, INPUT_WIDTH+2) - resize(feedback, INPUT_WIDTH+2);
                integrator <= integrator + error_signal;
                
                -- 1-bit quantization
                if integrator >= 0 then
                    ds_output <= '1';
                    feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);  -- +FS
                else
                    ds_output <= '0';
                    feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);   -- -FS
                end if;
                
                ready <= '1';
            else
                ds_output <= '0';
                ready <= '0';
            end if;
        end if;
    end process;
    
    ds_out <= ds_output;
    error_out <= error_signal;
    integrator_out <= integrator;
    
end behavioral;
```

---

## 🌊 **Delta-Sigma DAC Implementation**

### Multi-bit Delta-Sigma DAC
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity multi_bit_delta_sigma_dac is
    generic (
        INPUT_WIDTH : integer := 16;
        QUANTIZER_BITS : integer := 4;
        OSR : integer := 64  -- Oversampling ratio
    );
    port (
        clk         : in  std_logic;  -- High-speed clock
        clk_data    : in  std_logic;  -- Data clock (clk/OSR)
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
        data_valid  : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- Multi-bit output
        ds_out      : out std_logic_vector(QUANTIZER_BITS-1 downto 0);
        ds_valid    : out std_logic;
        
        -- Status
        ready       : out std_logic;
        
        -- Debug outputs
        noise_shaping_out : out signed(INPUT_WIDTH+3 downto 0)
    );
end multi_bit_delta_sigma_dac;

architecture behavioral of multi_bit_delta_sigma_dac is
    -- Input interpolation
    signal interpolated_data : signed(INPUT_WIDTH-1 downto 0);
    signal data_reg : signed(INPUT_WIDTH-1 downto 0);
    
    -- Delta-Sigma modulator
    signal integrator1 : signed(INPUT_WIDTH+3 downto 0);
    signal integrator2 : signed(INPUT_WIDTH+3 downto 0);
    signal error1, error2 : signed(INPUT_WIDTH+3 downto 0);
    signal quantizer_input : signed(INPUT_WIDTH+3 downto 0);
    signal quantizer_output : signed(QUANTIZER_BITS-1 downto 0);
    signal feedback : signed(INPUT_WIDTH-1 downto 0);
    
    -- Coefficients for 2nd order modulator
    constant A1 : signed(7 downto 0) := to_signed(64, 8);   -- 0.5 in Q7
    constant A2 : signed(7 downto 0) := to_signed(32, 8);   -- 0.25 in Q7
    
    signal osr_counter : integer range 0 to OSR-1;
    
begin
    
    -- Input data handling
    process(clk_data, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            
        elsif rising_edge(clk_data) then
            if data_valid = '1' and dac_enable = '1' then
                data_reg <= signed(data_in);
            end if;
        end if;
    end process;
    
    -- Interpolation (zero-order hold for simplicity)
    interpolated_data <= data_reg;
    
    -- 2nd order Delta-Sigma modulator
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            integrator1 <= (others => '0');
            integrator2 <= (others => '0');
            quantizer_output <= (others => '0');
            osr_counter <= 0;
            ds_valid <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                -- First integrator
                error1 <= resize(interpolated_data, INPUT_WIDTH+4) - resize(feedback, INPUT_WIDTH+4);
                integrator1 <= integrator1 + resize(error1 * A1, INPUT_WIDTH+4)(INPUT_WIDTH+10 downto 7);
                
                -- Second integrator  
                error2 <= integrator1 - resize(feedback, INPUT_WIDTH+4);
                integrator2 <= integrator2 + resize(error2 * A2, INPUT_WIDTH+4)(INPUT_WIDTH+10 downto 7);
                
                -- Multi-bit quantizer
                quantizer_input <= integrator2;
                
                -- Quantize to QUANTIZER_BITS
                if quantizer_input >= to_signed(2**(INPUT_WIDTH+2), INPUT_WIDTH+4) then
                    quantizer_output <= to_signed(2**(QUANTIZER_BITS-1)-1, QUANTIZER_BITS);
                elsif quantizer_input <= to_signed(-2**(INPUT_WIDTH+2), INPUT_WIDTH+4) then
                    quantizer_output <= to_signed(-2**(QUANTIZER_BITS-1), QUANTIZER_BITS);
                else
                    quantizer_output <= quantizer_input(INPUT_WIDTH+2 downto INPUT_WIDTH+3-QUANTIZER_BITS);
                end if;
                
                -- Feedback calculation
                feedback <= resize(quantizer_output, INPUT_WIDTH) * (2**(INPUT_WIDTH-QUANTIZER_BITS));
                
                -- Output timing
                if osr_counter = OSR-1 then
                    osr_counter <= 0;
                    ds_valid <= '1';
                else
                    osr_counter <= osr_counter + 1;
                    ds_valid <= '0';
                end if;
            else
                ds_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    ds_out <= std_logic_vector(quantizer_output);
    ready <= dac_enable;
    noise_shaping_out <= integrator2;
    
end behavioral;
```

### MASH Delta-Sigma DAC (Multi-stAge noise SHaping)
```vhdl
entity mash_delta_sigma_dac is
    generic (
        INPUT_WIDTH : integer := 16;
        STAGES : integer := 3
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(INPUT_WIDTH-1 downto 0);
        data_valid  : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- 1-bit output
        mash_out    : out std_logic;
        
        -- Status
        ready       : out std_logic;
        
        -- Debug - individual stage outputs
        stage1_out  : out std_logic;
        stage2_out  : out std_logic;
        stage3_out  : out std_logic
    );
end mash_delta_sigma_dac;

architecture behavioral of mash_delta_sigma_dac is
    -- Stage 1
    signal stage1_integrator : signed(INPUT_WIDTH+1 downto 0);
    signal stage1_error : signed(INPUT_WIDTH+1 downto 0);
    signal stage1_quantized : std_logic;
    signal stage1_feedback : signed(INPUT_WIDTH-1 downto 0);
    
    -- Stage 2
    signal stage2_integrator : signed(INPUT_WIDTH+1 downto 0);
    signal stage2_error : signed(INPUT_WIDTH+1 downto 0);
    signal stage2_quantized : std_logic;
    signal stage2_feedback : signed(INPUT_WIDTH-1 downto 0);
    
    -- Stage 3
    signal stage3_integrator : signed(INPUT_WIDTH+1 downto 0);
    signal stage3_error : signed(INPUT_WIDTH+1 downto 0);
    signal stage3_quantized : std_logic;
    signal stage3_feedback : signed(INPUT_WIDTH-1 downto 0);
    
    -- Digital noise shaping filter
    signal diff1_z1, diff1_z2 : std_logic;
    signal diff2_z1, diff2_z2 : std_logic;
    signal filtered_stage2, filtered_stage3 : std_logic;
    signal final_output : std_logic;
    
    signal data_reg : signed(INPUT_WIDTH-1 downto 0);
    
begin
    
    -- Input register
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
        elsif rising_edge(clk) then
            if data_valid = '1' and dac_enable = '1' then
                data_reg <= signed(data_in);
            end if;
        end if;
    end process;
    
    -- MASH stages
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- Stage 1
            stage1_integrator <= (others => '0');
            stage1_quantized <= '0';
            
            -- Stage 2
            stage2_integrator <= (others => '0');
            stage2_quantized <= '0';
            
            -- Stage 3
            stage3_integrator <= (others => '0');
            stage3_quantized <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                -- Stage 1: First-order modulator
                stage1_error <= resize(data_reg, INPUT_WIDTH+2) - resize(stage1_feedback, INPUT_WIDTH+2);
                stage1_integrator <= stage1_integrator + stage1_error;
                
                if stage1_integrator >= 0 then
                    stage1_quantized <= '1';
                    stage1_feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);
                else
                    stage1_quantized <= '0';
                    stage1_feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);
                end if;
                
                -- Stage 2: Process stage 1 quantization error
                stage2_error <= stage1_error - resize(stage2_feedback, INPUT_WIDTH+2);
                stage2_integrator <= stage2_integrator + stage2_error;
                
                if stage2_integrator >= 0 then
                    stage2_quantized <= '1';
                    stage2_feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);
                else
                    stage2_quantized <= '0';
                    stage2_feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);
                end if;
                
                -- Stage 3: Process stage 2 quantization error
                stage3_error <= stage2_error - resize(stage3_feedback, INPUT_WIDTH+2);
                stage3_integrator <= stage3_integrator + stage3_error;
                
                if stage3_integrator >= 0 then
                    stage3_quantized <= '1';
                    stage3_feedback <= to_signed(2**(INPUT_WIDTH-1)-1, INPUT_WIDTH);
                else
                    stage3_quantized <= '0';
                    stage3_feedback <= to_signed(-2**(INPUT_WIDTH-1), INPUT_WIDTH);
                end if;
            end if;
        end if;
    end process;
    
    -- Digital noise shaping filter
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            diff1_z1 <= '0';
            diff1_z2 <= '0';
            diff2_z1 <= '0';
            diff2_z2 <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                -- First differentiator: (1-z^-1)
                filtered_stage2 <= stage2_quantized xor diff1_z1;
                diff1_z1 <= stage2_quantized;
                
                -- Second differentiator: (1-z^-1)^2
                filtered_stage3 <= (stage3_quantized xor diff2_z1) xor diff2_z2;
                diff2_z1 <= stage3_quantized xor diff2_z1;
                diff2_z2 <= diff2_z1;
            end if;
        end if;
    end process;
    
    -- Combine outputs: Y = Y1 + (1-z^-1)*Y2 + (1-z^-1)^2*Y3
    final_output <= stage1_quantized xor filtered_stage2 xor filtered_stage3;
    
    -- Output assignments
    mash_out <= final_output;
    ready <= dac_enable;
    stage1_out <= stage1_quantized;
    stage2_out <= stage2_quantized;
    stage3_out <= stage3_quantized;
    
end behavioral;
```

---

## ⚡ **Current Steering DAC Implementation**

### High-Speed Current Steering DAC
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity current_steering_dac is
    generic (
        RESOLUTION : integer := 12;
        CURRENT_SOURCES : integer := 4095  -- 2^12 - 1
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- Current source control
        current_switches : out std_logic_vector(CURRENT_SOURCES-1 downto 0);
        
        -- Bias and reference
        bias_enable : out std_logic;
        ref_current : in  std_logic_vector(15 downto 0);
        
        -- Output current control
        iout_pos    : out std_logic;  -- Positive output enable
        iout_neg    : out std_logic;  -- Negative output enable
        
        -- Status
        ready       : out std_logic;
        settling    : out std_logic
    );
end current_steering_dac;

architecture behavioral of current_steering_dac is
    signal data_reg : unsigned(RESOLUTION-1 downto 0);
    signal thermometer_code : std_logic_vector(CURRENT_SOURCES-1 downto 0);
    signal settling_counter : integer range 0 to 15;
    
    -- Current source matching and calibration
    type current_trim_array is array (0 to CURRENT_SOURCES-1) of std_logic_vector(3 downto 0);
    signal current_trim : current_trim_array;
    
begin
    
    -- Data input and control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            settling_counter <= 0;
            ready <= '0';
            settling <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                if load_data = '1' then
                    data_reg <= unsigned(data_in);
                    settling_counter <= 10;  -- Settling time
                    settling <= '1';
                    ready <= '0';
                end if;
                
                if settling_counter > 0 then
                    settling_counter <= settling_counter - 1;
                else
                    settling <= '0';
                    ready <= '1';
                end if;
            else
                ready <= '0';
                settling <= '0';
            end if;
        end if;
    end process;
    
    -- Binary to thermometer decoder
    process(data_reg)
        variable temp_thermo : std_logic_vector(CURRENT_SOURCES-1 downto 0);
        variable data_int : integer;
    begin
        temp_thermo := (others => '0');
        data_int := to_integer(data_reg);
        
        -- Set bits from 0 to data_int-1
        for i in 0 to CURRENT_SOURCES-1 loop
            if i < data_int then
                temp_thermo(i) := '1';
            else
                temp_thermo(i) := '0';
            end if;
        end loop;
        
        thermometer_code <= temp_thermo;
    end process;
    
    -- Current switch control with settling optimization
    process(clk, rst_n)
        variable switch_sequence : std_logic_vector(CURRENT_SOURCES-1 downto 0);
    begin
        if rst_n = '0' then
            current_switches <= (others => '0');
            
        elsif rising_edge(clk) then
            if dac_enable = '1' and settling = '0' then
                -- Apply thermometer code to current switches
                current_switches <= thermometer_code;
            else
                -- During settling, gradually switch to minimize glitches
                current_switches <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Bias and output control
    bias_enable <= dac_enable;
    iout_pos <= dac_enable and ready;
    iout_neg <= dac_enable and ready;
    
end behavioral;
```

### Segmented Current Steering DAC
```vhdl
entity segmented_current_steering_dac is
    generic (
        TOTAL_BITS : integer := 14;
        MSB_BITS : integer := 6;   -- Thermometer coded MSBs
        LSB_BITS : integer := 8    -- Binary coded LSBs
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(TOTAL_BITS-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- MSB current sources (thermometer)
        msb_switches : out std_logic_vector((2**MSB_BITS)-2 downto 0);
        
        -- LSB current sources (binary)
        lsb_switches : out std_logic_vector(LSB_BITS-1 downto 0);
        
        -- Current scaling
        msb_current_scale : out std_logic_vector(7 downto 0);
        lsb_current_scale : out std_logic_vector(7 downto 0);
        
        -- Status
        ready       : out std_logic
    );
end segmented_current_steering_dac;

architecture behavioral of segmented_current_steering_dac is
    signal msb_data : std_logic_vector(MSB_BITS-1 downto 0);
    signal lsb_data : std_logic_vector(LSB_BITS-1 downto 0);
    
    signal msb_thermometer : std_logic_vector((2**MSB_BITS)-2 downto 0);
    signal lsb_binary : std_logic_vector(LSB_BITS-1 downto 0);
    
    constant MSB_WEIGHT : integer := 2**LSB_BITS;  -- MSB current is 256x LSB current
    
begin
    
    -- Split input data
    msb_data <= data_in(TOTAL_BITS-1 downto LSB_BITS);
    lsb_data <= data_in(LSB_BITS-1 downto 0);
    
    -- Data loading and control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            lsb_binary <= (others => '0');
            ready <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                if load_data = '1' then
                    lsb_binary <= lsb_data;
                end if;
                ready <= '1';
            else
                ready <= '0';
            end if;
        end if;
    end process;
    
    -- MSB thermometer decoder
    process(msb_data)
        variable msb_int : integer;
        variable temp_thermo : std_logic_vector((2**MSB_BITS)-2 downto 0);
    begin
        msb_int := to_integer(unsigned(msb_data));
        temp_thermo := (others => '0');
        
        for i in 0 to (2**MSB_BITS)-2 loop
            if i < msb_int then
                temp_thermo(i) := '1';
            end if;
        end loop;
        
        msb_thermometer <= temp_thermo;
    end process;
    
    -- Output assignments
    msb_switches <= msb_thermometer when dac_enable = '1' else (others => '0');
    lsb_switches <= lsb_binary when dac_enable = '1' else (others => '0');
    
    -- Current scaling factors
    msb_current_scale <= std_logic_vector(to_unsigned(MSB_WEIGHT, 8));
    lsb_current_scale <= x"01";  -- Unit current
    
end behavioral;
```

---

## 🔗 **String DAC Implementation**

### Resistor String DAC with Decoder
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity string_dac is
    generic (
        RESOLUTION : integer := 8  -- Practical limit for string DACs
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Digital input
        data_in     : in  std_logic_vector(RESOLUTION-1 downto 0);
        load_data   : in  std_logic;
        
        -- Control
        dac_enable  : in  std_logic;
        
        -- String tap selection
        string_select : out std_logic_vector((2**RESOLUTION)-1 downto 0);
        
        -- Reference voltages
        vref_top    : in  std_logic_vector(15 downto 0);
        vref_bottom : in  std_logic_vector(15 downto 0);
        
        -- Analog output (calculated)
        analog_out  : out std_logic_vector(15 downto 0);
        
        -- Status
        ready       : out std_logic
    );
end string_dac;

architecture behavioral of string_dac is
    constant NUM_TAPS : integer := 2**RESOLUTION;
    
    signal data_reg : unsigned(RESOLUTION-1 downto 0);
    signal decoder_out : std_logic_vector(NUM_TAPS-1 downto 0);
    signal selected_tap : integer range 0 to NUM_TAPS-1;
    
    -- Voltage calculation
    signal vref_range : unsigned(15 downto 0);
    signal tap_voltage : unsigned(31 downto 0);
    
begin
    
    -- Data input control
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            data_reg <= (others => '0');
            ready <= '0';
            
        elsif rising_edge(clk) then
            if dac_enable = '1' then
                if load_data = '1' then
                    data_reg <= unsigned(data_in);
                end if;
                ready <= '1';
            else
                ready <= '0';
            end if;
        end if;
    end process;
    
    -- Binary to one-hot decoder
    process(data_reg, dac_enable)
        variable temp_select : std_logic_vector(NUM_TAPS-1 downto 0);
        variable tap_index : integer;
    begin
        temp_select := (others => '0');
        
        if dac_enable = '1' then
            tap_index := to_integer(data_reg);
            if tap_index < NUM_TAPS then
                temp_select(tap_index) := '1';
            end if;
        end if;
        
        decoder_out <= temp_select;
        selected_tap <= tap_index;
    end process;
    
    -- Voltage calculation for selected tap
    process(selected_tap, vref_top, vref_bottom)
    begin
        vref_range <= unsigned(vref_top) - unsigned(vref_bottom);
        
        -- Vout = Vref_bottom + (tap_number / (2^N - 1)) * (Vref_top - Vref_bottom)
        tap_voltage <= to_unsigned(selected_tap, 16) * vref_range;
        analog_out <= std_logic_vector(unsigned(vref_bottom) + tap_voltage(31 downto 16));
    end process;
    
    -- Output string selection
    string_select <= decoder_out;
    
end behavioral;
```

---

## 🎛️ **DAC Interface Controllers**

### Multi-Channel DAC Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity multi_channel_dac_controller is
    generic (
        NUM_CHANNELS : integer := 8;
        RESOLUTION : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Channel data inputs
        ch0_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch1_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch2_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch3_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch4_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch5_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch6_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        ch7_data    : in  std_logic_vector(RESOLUTION-1 downto 0);
        
        -- Channel control
        channel_enable : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        update_all  : in  std_logic;
        update_single : in  std_logic;
        channel_select : in  std_logic_vector(2 downto 0);
        
        -- DAC interface
        dac_data    : out std_logic_vector(RESOLUTION-1 downto 0);
        dac_channel : out std_logic_vector(2 downto 0);
        dac_load    : out std_logic;
        dac_ready   : in  std_logic;
        
        -- Status
        update_complete : out std_logic;
        busy        : out std_logic
    );
end multi_channel_dac_controller;

architecture behavioral of multi_channel_dac_controller is
    type state_type is (IDLE, UPDATE_CHANNEL, WAIT_READY);
    signal state : state_type;
    
    type data_array is array (0 to NUM_CHANNELS-1) of std_logic_vector(RESOLUTION-1 downto 0);
    signal channel_data : data_array;
    
    signal current_channel : integer range 0 to NUM_CHANNELS-1;
    signal update_counter : integer range 0 to NUM_CHANNELS;
    
begin
    
    -- Map input data to array
    channel_data(0) <= ch0_data;
    channel_data(1) <= ch1_data;
    channel_data(2) <= ch2_data;
    channel_data(3) <= ch3_data;
    channel_data(4) <= ch4_data;
    channel_data(5) <= ch5_data;
    channel_data(6) <= ch6_data;
    channel_data(7) <= ch7_data;
    
    -- Main control process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            current_channel <= 0;
            update_counter <= 0;
            dac_load <= '0';
            update_complete <= '0';
            busy <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    dac_load <= '0';
                    update_complete <= '0';
                    busy <= '0';
                    
                    if update_all = '1' then
                        -- Update all enabled channels
                        current_channel <= 0;
                        update_counter <= 0;
                        state <= UPDATE_CHANNEL;
                        busy <= '1';
                        
                    elsif update_single = '1' then
                        -- Update single channel
                        current_channel <= to_integer(unsigned(channel_select));
                        update_counter <= 1;
                        state <= UPDATE_CHANNEL;
                        busy <= '1';
                    end if;
                
                when UPDATE_CHANNEL =>
                    if channel_enable(current_channel) = '1' then
                        dac_data <= channel_data(current_channel);
                        dac_channel <= std_logic_vector(to_unsigned(current_channel, 3));
                        dac_load <= '1';
                        state <= WAIT_READY;
                    else
                        -- Skip disabled channel
                        if update_counter < NUM_CHANNELS then
                            current_channel <= (current_channel + 1) mod NUM_CHANNELS;
                            update_counter <= update_counter + 1;
                        else
                            state <= IDLE;
                            update_complete <= '1';
                        end if;
                    end if;
                
                when WAIT_READY =>
                    dac_load <= '0';
                    if dac_ready = '1' then
                        if update_counter < NUM_CHANNELS then
                            current_channel <= (current_channel + 1) mod NUM_CHANNELS;
                            update_counter <= update_counter + 1;
                            state <= UPDATE_CHANNEL;
                        else
                            state <= IDLE;
                            update_complete <= '1';
                        end if;
                    end if;
            end case;
        end if;
    end process;
    
end behavioral;
```

---

## 🔧 **Calibration and Correction**

### DAC Linearity Calibration
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_linearity_calibration is
    generic (
        DATA_WIDTH : integer := 12;
        CAL_POINTS : integer := 16  -- Number of calibration points
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Input data
        raw_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_valid  : in  std_logic;
        
        -- Calibration table interface
        cal_addr    : out std_logic_vector(3 downto 0);  -- log2(CAL_POINTS)
        cal_data    : in  std_logic_vector(DATA_WIDTH+3 downto 0);  -- Correction values
        
        -- Calibrated output
        cal_data_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
        cal_valid   : out std_logic;
        
        -- Control
        cal_enable  : in  std_logic;
        cal_mode    : in  std_logic_vector(1 downto 0)  -- 00: bypass, 01: linear, 10: cubic
    );
end dac_linearity_calibration;

architecture behavioral of dac_linearity_calibration is
    signal input_reg : unsigned(DATA_WIDTH-1 downto 0);
    signal segment_index : unsigned(3 downto 0);
    signal segment_fraction : unsigned(DATA_WIDTH-5 downto 0);
    
    -- Interpolation signals
    signal cal_point_low : signed(DATA_WIDTH+3 downto 0);
    signal cal_point_high : signed(DATA_WIDTH+3 downto 0);
    signal interpolated : signed(DATA_WIDTH+7 downto 0);
    
    signal valid_pipe : std_logic_vector(2 downto 0);
    
begin
    
    -- Input processing
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            input_reg <= (others => '0');
            segment_index <= (others => '0');
            segment_fraction <= (others => '0');
            valid_pipe <= (others => '0');
            
        elsif rising_edge(clk) then
            -- Pipeline stage 1: Segment calculation
            input_reg <= unsigned(raw_data);
            
            -- Divide input into segments for calibration lookup
            segment_index <= input_reg(DATA_WIDTH-1 downto DATA_WIDTH-4);
            segment_fraction <= input_reg(DATA_WIDTH-5 downto 0);
            
            -- Valid pipeline
            valid_pipe <= valid_pipe(1 downto 0) & data_valid;
        end if;
    end process;
    
    -- Calibration table lookup
    cal_addr <= std_logic_vector(segment_index);
    
    -- Interpolation process
    process(clk, rst_n)
        variable next_segment : unsigned(3 downto 0);
    begin
        if rst_n = '0' then
            cal_point_low <= (others => '0');
            interpolated <= (others => '0');
            
        elsif rising_edge(clk) then
            if cal_enable = '1' then
                -- Store current calibration point
                cal_point_low <= signed(cal_data);
                
                -- Linear interpolation between calibration points
                case cal_mode is
                    when "01" =>  -- Linear interpolation
                        -- Simple linear interpolation
                        interpolated <= cal_point_low * resize(signed(segment_fraction), DATA_WIDTH+4);
                        
                    when "10" =>  -- Cubic interpolation (simplified)
                        -- Cubic interpolation (requires more calibration points)
                        interpolated <= cal_point_low * resize(signed(segment_fraction), DATA_WIDTH+4);
                        
                    when others =>  -- Bypass
                        interpolated <= resize(signed(raw_data), DATA_WIDTH+8) & "00000000";
                end case;
            else
                interpolated <= resize(signed(raw_data), DATA_WIDTH+8) & "00000000";
            end if;
        end if;
    end process;
    
    -- Output scaling and limiting
    process(clk, rst_n)
        variable scaled_output : signed(DATA_WIDTH-1 downto 0);
    begin
        if rst_n = '0' then
            cal_data_out <= (others => '0');
            cal_valid <= '0';
            
        elsif rising_edge(clk) then
            -- Scale back to original width
            scaled_output := interpolated(DATA_WIDTH+7 downto 8);
            
            -- Limit to valid range
            if scaled_output > to_signed(2**(DATA_WIDTH-1)-1, DATA_WIDTH) then
                cal_data_out <= std_logic_vector(to_signed(2**(DATA_WIDTH-1)-1, DATA_WIDTH));
            elsif scaled_output < to_signed(-2**(DATA_WIDTH-1), DATA_WIDTH) then
                cal_data_out <= std_logic_vector(to_signed(-2**(DATA_WIDTH-1), DATA_WIDTH));
            else
                cal_data_out <= std_logic_vector(scaled_output);
            end if;
            
            cal_valid <= valid_pipe(2);
        end if;
    end process;
    
end behavioral;
```

---

## 🧪 **Testing and Verification**

### DAC Testbench with Waveform Generation
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity dac_testbench is
end dac_testbench;

architecture behavioral of dac_testbench is
    constant CLK_PERIOD : time := 10 ns;
    constant RESOLUTION : integer := 12;
    
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal data_in : std_logic_vector(RESOLUTION-1 downto 0);
    signal load_data : std_logic := '0';
    signal dac_enable : std_logic := '0';
    signal analog_out : std_logic_vector(15 downto 0);
    signal ready : std_logic;
    
    -- Test parameters
    signal test_mode : integer := 0;  -- 0: sine, 1: ramp, 2: step
    signal frequency : real := 1000.0;  -- 1 kHz
    signal amplitude : real := 0.8;     -- 80% of full scale
    
    component r2r_dac is
        generic (RESOLUTION : integer := 12);
        port (
            clk : in std_logic;
            rst_n : in std_logic;
            data_in : in std_logic_vector(RESOLUTION-1 downto 0);
            load_data : in std_logic;
            vref_high : in std_logic_vector(15 downto 0);
            vref_low : in std_logic_vector(15 downto 0);
            switch_ctrl : out std_logic_vector(RESOLUTION-1 downto 0);
            analog_out : out std_logic_vector(15 downto 0);
            ready : out std_logic;
            dac_enable : in std_logic
        );
    end component;
    
begin
    
    -- Clock generation
    clk <= not clk after CLK_PERIOD/2;
    
    -- Reset generation
    rst_n <= '0', '1' after 100 ns;
    
    -- DUT instantiation
    dut: r2r_dac
        generic map (RESOLUTION => RESOLUTION)
        port map (
            clk => clk,
            rst_n => rst_n,
            data_in => data_in,
            load_data => load_data,
            vref_high => x"FFFF",
            vref_low => x"0000",
            switch_ctrl => open,
            analog_out => analog_out,
            ready => ready,
            dac_enable => dac_enable
        );
    
    -- Enable DAC after reset
    dac_enable <= '1' after 200 ns;
    
    -- Waveform generation process
    process
        variable phase : real := 0.0;
        variable sample_time : real := 0.0;
        variable waveform_val : real;
        variable digital_val : integer;
        constant sample_rate : real := 100000.0;  -- 100 kHz
    begin
        wait until rst_n = '1';
        wait until dac_enable = '1';
        
        while true loop
            case test_mode is
                when 0 =>  -- Sine wave
                    waveform_val := amplitude * sin(2.0 * MATH_PI * frequency * sample_time);
                    
                when 1 =>  -- Ramp wave
                    waveform_val := amplitude * (2.0 * (sample_time * frequency - floor(sample_time * frequency)) - 1.0);
                    
                when 2 =>  -- Step response
                    if sample_time < 0.001 then
                        waveform_val := 0.0;
                    else
                        waveform_val := amplitude;
                    end if;
                    
                when others =>
                    waveform_val := 0.0;
            end case;
            
            -- Convert to digital value
            digital_val := integer((waveform_val + 1.0) * real(2**(RESOLUTION-1)));
            
            -- Limit to valid range
            if digital_val > (2**RESOLUTION - 1) then
                digital_val := 2**RESOLUTION - 1;
            elsif digital_val < 0 then
                digital_val := 0;
            end if;
            
            data_in <= std_logic_vector(to_unsigned(digital_val, RESOLUTION));
            
            -- Load data
            load_data <= '1';
            wait for CLK_PERIOD;
            load_data <= '0';
            
            -- Wait for next sample
            wait for CLK_PERIOD * integer(100000000.0 / sample_rate);
            
            sample_time := sample_time + 1.0 / sample_rate;
        end loop;
    end process;
    
    -- Test mode control
    process
    begin
        wait for 10 ms;
        test_mode <= 1;  -- Switch to ramp
        wait for 10 ms;
        test_mode <= 2;  -- Switch to step
        wait for 10 ms;
        test_mode <= 0;  -- Back to sine
        wait;
    end process;
    
    -- Data logging
    process
        file output_file : text open write_mode is "dac_output.txt";
        variable line_out : line;
        variable sample_count : integer := 0;
    begin
        wait until rst_n = '1';
        
        while sample_count < 10000 loop
            wait until load_data = '1';
            wait for CLK_PERIOD;
            
            write(line_out, sample_count);
            write(line_out, string'(" "));
            write(line_out, to_integer(unsigned(data_in)));
            write(line_out, string'(" "));
            write(line_out, to_integer(unsigned(analog_out)));
            writeline(output_file, line_out);
            
            sample_count := sample_count + 1;
        end loop;
        
        report "Test completed - 10000 samples logged";
        wait;
    end process;
    
end behavioral;
```

---

## 📊 **Performance Analysis and Metrics**

### DAC Performance Monitor
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_performance_monitor is
    generic (
        DATA_WIDTH : integer := 12
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- DAC data monitoring
        dac_input   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dac_output  : in  std_logic_vector(15 downto 0);
        data_valid  : in  std_logic;
        
        -- Performance metrics
        update_rate : out std_logic_vector(31 downto 0);
        linearity_error : out std_logic_vector(DATA_WIDTH-1 downto 0);
        settling_time : out std_logic_vector(15 downto 0);
        
        -- THD analysis
        thd_result  : out std_logic_vector(15 downto 0);
        snr_result  : out std_logic_vector(15 downto 0);
        
        -- Control
        reset_stats : in  std_logic;
        enable_mon  : in  std_logic
    );
end dac_performance_monitor;

architecture behavioral of dac_performance_monitor is
    signal update_counter : unsigned(31 downto 0);
    signal time_counter : unsigned(31 downto 0);
    
    -- Linearity measurement
    signal expected_output : unsigned(15 downto 0);
    signal actual_output : unsigned(15 downto 0);
    signal linearity_err : signed(DATA_WIDTH-1 downto 0);
    
    -- Settling time measurement
    signal prev_input : unsigned(DATA_WIDTH-1 downto 0);
    signal settling_counter : unsigned(15 downto 0);
    signal settling_active : std_logic;
    
    -- THD calculation (simplified)
    signal fundamental_power : unsigned(31 downto 0);
    signal harmonic_power : unsigned(31 downto 0);
    
begin
    
    -- Main monitoring process
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            update_counter <= (others => '0');
            time_counter <= (others => '0');
            prev_input <= (others => '0');
            settling_counter <= (others => '0');
            settling_active <= '0';
            
        elsif rising_edge(clk) then
            if reset_stats = '1' then
                update_counter <= (others => '0');
                time_counter <= (others => '0');
                
            elsif enable_mon = '1' then
                time_counter <= time_counter + 1;
                
                if data_valid = '1' then
                    update_counter <= update_counter + 1;
                    
                    -- Linearity error calculation
                    expected_output <= unsigned(dac_input) * 16;  -- Scale to 16-bit
                    actual_output <= unsigned(dac_output);
                    linearity_err <= signed(actual_output) - signed(expected_output);
                    
                    -- Settling time measurement
                    if unsigned(dac_input) /= prev_input then
                        settling_active <= '1';
                        settling_counter <= (others => '0');
                    elsif settling_active = '1' then
                        settling_counter <= settling_counter + 1;
                        -- Check if settled (simplified)
                        if abs(linearity_err) < 2 then
                            settling_active <= '0';
                        end if;
                    end if;
                    
                    prev_input <= unsigned(dac_input);
                end if;
            end if;
        end if;
    end process;
    
    -- Update rate calculation
    process(clk, rst_n)
        variable rate_calc : unsigned(31 downto 0);
    begin
        if rst_n = '0' then
            rate_calc := (others => '0');
        elsif rising_edge(clk) then
            if time_counter > 0 then
                rate_calc := (update_counter * 100000000) / time_counter;  -- Assuming 100MHz clock
            end if;
        end if;
        update_rate <= std_logic_vector(rate_calc);
    end process;
    
    -- Output assignments
    linearity_error <= std_logic_vector(linearity_err);
    settling_time <= std_logic_vector(settling_counter);
    
    -- Simplified THD calculation (would need FFT in practice)
    thd_result <= x"0010";  -- Placeholder: 1% THD
    snr_result <= x"0060";  -- Placeholder: 96 dB SNR
    
end behavioral;
```

---

## 🎯 **Summary and Best Practices**

### DAC Design Guidelines

1. **Architecture Selection**:
   - **R-2R Ladder**: Good for moderate resolution (8-12 bits), simple implementation
   - **PWM**: Excellent for audio applications, requires good filtering
   - **Delta-Sigma**: Best for high resolution, oversampled systems
   - **Current Steering**: Highest speed, complex calibration required
   - **String**: Limited resolution but excellent linearity

2. **Performance Considerations**:
   - **Settling Time**: Critical for high-speed applications
   - **Linearity**: Use calibration for precision applications
   - **Glitch Energy**: Minimize with proper switching sequences
   - **Power Consumption**: Consider sleep modes and power-down

3. **Implementation Tips**:
   - Use synchronous design practices
   - Implement proper reset strategies
   - Consider thermal effects on precision
   - Plan for calibration and trimming
   - Include comprehensive testbenches

4. **Testing and Verification**:
   - Generate standard test waveforms
   - Measure key performance metrics
   - Verify across temperature and voltage ranges
   - Test for monotonicity and missing codes

---

## 📚 **Additional Resources**

- **IEEE Standards**: IEEE 1241 (ADC/DAC Testing)
- **Application Notes**: Manufacturer-specific design guides
- **Simulation Tools**: SPICE models for analog verification
- **Measurement Equipment**: High-precision DMMs, spectrum analyzers

---

*This cheatsheet provides comprehensive VHDL implementations for various DAC architectures. Each example includes detailed comments and can be adapted for specific requirements.*