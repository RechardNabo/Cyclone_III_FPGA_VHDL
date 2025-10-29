# 🚀 **DMA (Direct Memory Access) VHDL Cheatsheet**

## 📋 **Table of Contents**
1. [DMA Fundamentals](#dma-fundamentals)
2. [Basic DMA Controller](#basic-dma-controller)
3. [Multi-Channel DMA Controller](#multi-channel-dma-controller)
4. [Scatter-Gather DMA](#scatter-gather-dma)
5. [AXI4 DMA Controller](#axi4-dma-controller)
6. [Memory-to-Memory DMA](#memory-to-memory-dma)
7. [Stream DMA Controller](#stream-dma-controller)
8. [DMA Arbitration and Priority](#dma-arbitration-and-priority)
9. [Advanced DMA Features](#advanced-dma-features)
10. [Testing and Verification](#testing-and-verification)

---

## 🎯 **DMA Fundamentals**

### Basic DMA Entity Template
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity generic_dma_controller is
    generic (
        ADDR_WIDTH : integer := 32;
        DATA_WIDTH : integer := 32;
        NUM_CHANNELS : integer := 4;
        MAX_BURST_SIZE : integer := 256
    );
    port (
        -- Clock and Reset
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- CPU Interface (Register Access)
        cpu_addr    : in  std_logic_vector(7 downto 0);
        cpu_wdata   : in  std_logic_vector(31 downto 0);
        cpu_rdata   : out std_logic_vector(31 downto 0);
        cpu_we      : in  std_logic;
        cpu_re      : in  std_logic;
        cpu_ack     : out std_logic;
        
        -- Memory Interface (Master)
        mem_addr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_wdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_rdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_we      : out std_logic;
        mem_re      : out std_logic;
        mem_ready   : in  std_logic;
        mem_valid   : in  std_logic;
        
        -- Peripheral Interface
        periph_req  : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        periph_ack  : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        periph_data : in  std_logic_vector(DATA_WIDTH*NUM_CHANNELS-1 downto 0);
        
        -- Interrupt Interface
        dma_irq     : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        dma_irq_combined : out std_logic;
        
        -- Status and Control
        dma_enable  : in  std_logic;
        dma_busy    : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        error_flag  : out std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end generic_dma_controller;
```

---

## 🔧 **Basic DMA Controller**

### Single Channel DMA with Basic Transfer Modes
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity basic_dma_controller is
    generic (
        ADDR_WIDTH : integer := 32;
        DATA_WIDTH : integer := 32
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Control Registers
        src_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        dst_addr    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        transfer_count : in  std_logic_vector(15 downto 0);
        transfer_mode  : in  std_logic_vector(1 downto 0);  -- 00: M2M, 01: M2P, 10: P2M, 11: P2P
        
        -- Control Signals
        dma_start   : in  std_logic;
        dma_enable  : in  std_logic;
        
        -- Memory Interface
        mem_addr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_wdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_rdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_we      : out std_logic;
        mem_re      : out std_logic;
        mem_ready   : in  std_logic;
        mem_valid   : in  std_logic;
        
        -- Peripheral Interface
        periph_data_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        periph_data_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
        periph_req  : in  std_logic;
        periph_ack  : out std_logic;
        
        -- Status
        dma_busy    : out std_logic;
        dma_done    : out std_logic;
        dma_error   : out std_logic
    );
end basic_dma_controller;

architecture behavioral of basic_dma_controller is
    type dma_state_type is (IDLE, READ_SETUP, READ_DATA, WRITE_SETUP, WRITE_DATA, COMPLETE, ERROR_STATE);
    signal dma_state : dma_state_type;
    
    signal current_src_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal current_dst_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal remaining_count : unsigned(15 downto 0);
    signal data_buffer : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal timeout_counter : unsigned(15 downto 0);
    constant TIMEOUT_LIMIT : unsigned(15 downto 0) := x"FFFF";
    
begin
    
    -- Main DMA State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            dma_state <= IDLE;
            current_src_addr <= (others => '0');
            current_dst_addr <= (others => '0');
            remaining_count <= (others => '0');
            data_buffer <= (others => '0');
            timeout_counter <= (others => '0');
            
            mem_addr <= (others => '0');
            mem_wdata <= (others => '0');
            mem_we <= '0';
            mem_re <= '0';
            periph_data_out <= (others => '0');
            periph_ack <= '0';
            
            dma_busy <= '0';
            dma_done <= '0';
            dma_error <= '0';
            
        elsif rising_edge(clk) then
            -- Default signal states
            mem_we <= '0';
            mem_re <= '0';
            periph_ack <= '0';
            dma_done <= '0';
            
            case dma_state is
                when IDLE =>
                    dma_busy <= '0';
                    dma_error <= '0';
                    timeout_counter <= (others => '0');
                    
                    if dma_start = '1' and dma_enable = '1' then
                        current_src_addr <= unsigned(src_addr);
                        current_dst_addr <= unsigned(dst_addr);
                        remaining_count <= unsigned(transfer_count);
                        dma_busy <= '1';
                        
                        -- Determine first operation based on transfer mode
                        case transfer_mode is
                            when "00" | "01" =>  -- M2M or M2P: Start with memory read
                                dma_state <= READ_SETUP;
                            when "10" =>         -- P2M: Start with peripheral read
                                if periph_req = '1' then
                                    data_buffer <= periph_data_in;
                                    periph_ack <= '1';
                                    dma_state <= WRITE_SETUP;
                                end if;
                            when "11" =>         -- P2P: Direct peripheral transfer
                                if periph_req = '1' then
                                    periph_data_out <= periph_data_in;
                                    periph_ack <= '1';
                                    remaining_count <= remaining_count - 1;
                                    if remaining_count = 1 then
                                        dma_state <= COMPLETE;
                                    end if;
                                end if;
                            when others =>
                                dma_state <= ERROR_STATE;
                        end case;
                    end if;
                
                when READ_SETUP =>
                    mem_addr <= std_logic_vector(current_src_addr);
                    mem_re <= '1';
                    dma_state <= READ_DATA;
                    timeout_counter <= (others => '0');
                
                when READ_DATA =>
                    timeout_counter <= timeout_counter + 1;
                    
                    if mem_valid = '1' then
                        data_buffer <= mem_rdata;
                        current_src_addr <= current_src_addr + (DATA_WIDTH/8);
                        
                        -- Determine next state based on transfer mode
                        case transfer_mode is
                            when "00" =>  -- M2M: Write to memory
                                dma_state <= WRITE_SETUP;
                            when "01" =>  -- M2P: Write to peripheral
                                periph_data_out <= mem_rdata;
                                periph_ack <= '1';
                                remaining_count <= remaining_count - 1;
                                if remaining_count = 1 then
                                    dma_state <= COMPLETE;
                                else
                                    dma_state <= READ_SETUP;
                                end if;
                            when others =>
                                dma_state <= ERROR_STATE;
                        end case;
                        
                    elsif timeout_counter = TIMEOUT_LIMIT then
                        dma_state <= ERROR_STATE;
                    end if;
                
                when WRITE_SETUP =>
                    mem_addr <= std_logic_vector(current_dst_addr);
                    mem_wdata <= data_buffer;
                    mem_we <= '1';
                    dma_state <= WRITE_DATA;
                    timeout_counter <= (others => '0');
                
                when WRITE_DATA =>
                    timeout_counter <= timeout_counter + 1;
                    
                    if mem_ready = '1' then
                        current_dst_addr <= current_dst_addr + (DATA_WIDTH/8);
                        remaining_count <= remaining_count - 1;
                        
                        if remaining_count = 1 then
                            dma_state <= COMPLETE;
                        else
                            -- Continue with next transfer
                            case transfer_mode is
                                when "00" =>  -- M2M: Read next data
                                    dma_state <= READ_SETUP;
                                when "10" =>  -- P2M: Wait for peripheral
                                    dma_state <= IDLE;  -- Wait for next peripheral request
                                when others =>
                                    dma_state <= ERROR_STATE;
                            end case;
                        end if;
                        
                    elsif timeout_counter = TIMEOUT_LIMIT then
                        dma_state <= ERROR_STATE;
                    end if;
                
                when COMPLETE =>
                    dma_done <= '1';
                    dma_busy <= '0';
                    dma_state <= IDLE;
                
                when ERROR_STATE =>
                    dma_error <= '1';
                    dma_busy <= '0';
                    dma_state <= IDLE;
                
                when others =>
                    dma_state <= IDLE;
            end case;
        end if;
    end process;
    
end behavioral;
```

---

## 🔀 **Multi-Channel DMA Controller**

### 4-Channel DMA with Round-Robin Arbitration
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity multi_channel_dma is
    generic (
        NUM_CHANNELS : integer := 4;
        ADDR_WIDTH : integer := 32;
        DATA_WIDTH : integer := 32
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Channel Configuration (per channel)
        ch_src_addr : in  std_logic_vector(NUM_CHANNELS*ADDR_WIDTH-1 downto 0);
        ch_dst_addr : in  std_logic_vector(NUM_CHANNELS*ADDR_WIDTH-1 downto 0);
        ch_count    : in  std_logic_vector(NUM_CHANNELS*16-1 downto 0);
        ch_mode     : in  std_logic_vector(NUM_CHANNELS*2-1 downto 0);
        
        -- Channel Control
        ch_enable   : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        ch_start    : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        ch_priority : in  std_logic_vector(NUM_CHANNELS*2-1 downto 0);
        
        -- Shared Memory Interface
        mem_addr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_wdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_rdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_we      : out std_logic;
        mem_re      : out std_logic;
        mem_ready   : in  std_logic;
        mem_valid   : in  std_logic;
        
        -- Peripheral Interfaces (per channel)
        periph_req  : in  std_logic_vector(NUM_CHANNELS-1 downto 0);
        periph_ack  : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        periph_data_in  : in  std_logic_vector(NUM_CHANNELS*DATA_WIDTH-1 downto 0);
        periph_data_out : out std_logic_vector(NUM_CHANNELS*DATA_WIDTH-1 downto 0);
        
        -- Status
        ch_busy     : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        ch_done     : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        ch_error    : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        ch_irq      : out std_logic_vector(NUM_CHANNELS-1 downto 0)
    );
end multi_channel_dma;

architecture behavioral of multi_channel_dma is
    -- Channel state machine
    type channel_state_type is (CH_IDLE, CH_READ_SETUP, CH_READ_DATA, CH_WRITE_SETUP, CH_WRITE_DATA, CH_COMPLETE);
    type channel_state_array is array (0 to NUM_CHANNELS-1) of channel_state_type;
    signal ch_state : channel_state_array;
    
    -- Channel registers
    type addr_array is array (0 to NUM_CHANNELS-1) of unsigned(ADDR_WIDTH-1 downto 0);
    type count_array is array (0 to NUM_CHANNELS-1) of unsigned(15 downto 0);
    type data_array is array (0 to NUM_CHANNELS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal ch_current_src : addr_array;
    signal ch_current_dst : addr_array;
    signal ch_remaining : count_array;
    signal ch_data_buffer : data_array;
    
    -- Arbitration
    signal current_channel : integer range 0 to NUM_CHANNELS-1;
    signal arbiter_grant : std_logic_vector(NUM_CHANNELS-1 downto 0);
    signal channel_request : std_logic_vector(NUM_CHANNELS-1 downto 0);
    
    -- Memory interface multiplexing
    signal mux_mem_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal mux_mem_wdata : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mux_mem_we : std_logic;
    signal mux_mem_re : std_logic;
    
begin
    
    -- Channel Configuration Unpacking
    gen_channel_config: for i in 0 to NUM_CHANNELS-1 generate
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                ch_current_src(i) <= (others => '0');
                ch_current_dst(i) <= (others => '0');
                ch_remaining(i) <= (others => '0');
                
            elsif rising_edge(clk) then
                if ch_start(i) = '1' and ch_enable(i) = '1' then
                    ch_current_src(i) <= unsigned(ch_src_addr((i+1)*ADDR_WIDTH-1 downto i*ADDR_WIDTH));
                    ch_current_dst(i) <= unsigned(ch_dst_addr((i+1)*ADDR_WIDTH-1 downto i*ADDR_WIDTH));
                    ch_remaining(i) <= unsigned(ch_count((i+1)*16-1 downto i*16));
                end if;
            end if;
        end process;
    end generate;
    
    -- Round-Robin Arbitration
    process(clk, rst_n)
        variable next_channel : integer range 0 to NUM_CHANNELS-1;
    begin
        if rst_n = '0' then
            current_channel <= 0;
            arbiter_grant <= (others => '0');
            
        elsif rising_edge(clk) then
            arbiter_grant <= (others => '0');
            
            -- Find next requesting channel
            next_channel := current_channel;
            for i in 0 to NUM_CHANNELS-1 loop
                if channel_request((current_channel + i) mod NUM_CHANNELS) = '1' then
                    next_channel := (current_channel + i) mod NUM_CHANNELS;
                    exit;
                end if;
            end loop;
            
            if channel_request(next_channel) = '1' then
                arbiter_grant(next_channel) <= '1';
                current_channel <= (next_channel + 1) mod NUM_CHANNELS;
            end if;
        end if;
    end process;
    
    -- Channel State Machines
    gen_channels: for i in 0 to NUM_CHANNELS-1 generate
        process(clk, rst_n)
        begin
            if rst_n = '0' then
                ch_state(i) <= CH_IDLE;
                ch_data_buffer(i) <= (others => '0');
                ch_busy(i) <= '0';
                ch_done(i) <= '0';
                ch_error(i) <= '0';
                ch_irq(i) <= '0';
                
            elsif rising_edge(clk) then
                -- Default values
                ch_done(i) <= '0';
                ch_irq(i) <= '0';
                
                case ch_state(i) is
                    when CH_IDLE =>
                        ch_busy(i) <= '0';
                        ch_error(i) <= '0';
                        
                        if ch_start(i) = '1' and ch_enable(i) = '1' then
                            ch_busy(i) <= '1';
                            
                            -- Determine transfer mode
                            case ch_mode(i*2+1 downto i*2) is
                                when "00" | "01" =>  -- M2M or M2P
                                    ch_state(i) <= CH_READ_SETUP;
                                when "10" =>         -- P2M
                                    if periph_req(i) = '1' then
                                        ch_data_buffer(i) <= periph_data_in((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH);
                                        ch_state(i) <= CH_WRITE_SETUP;
                                    end if;
                                when others =>
                                    ch_error(i) <= '1';
                            end case;
                        end if;
                    
                    when CH_READ_SETUP =>
                        if arbiter_grant(i) = '1' then
                            ch_state(i) <= CH_READ_DATA;
                        end if;
                    
                    when CH_READ_DATA =>
                        if mem_valid = '1' and arbiter_grant(i) = '1' then
                            ch_data_buffer(i) <= mem_rdata;
                            ch_current_src(i) <= ch_current_src(i) + (DATA_WIDTH/8);
                            
                            case ch_mode(i*2+1 downto i*2) is
                                when "00" =>  -- M2M
                                    ch_state(i) <= CH_WRITE_SETUP;
                                when "01" =>  -- M2P
                                    ch_remaining(i) <= ch_remaining(i) - 1;
                                    if ch_remaining(i) = 1 then
                                        ch_state(i) <= CH_COMPLETE;
                                    else
                                        ch_state(i) <= CH_READ_SETUP;
                                    end if;
                                when others =>
                                    ch_error(i) <= '1';
                                    ch_state(i) <= CH_IDLE;
                            end case;
                        end if;
                    
                    when CH_WRITE_SETUP =>
                        if arbiter_grant(i) = '1' then
                            ch_state(i) <= CH_WRITE_DATA;
                        end if;
                    
                    when CH_WRITE_DATA =>
                        if mem_ready = '1' and arbiter_grant(i) = '1' then
                            ch_current_dst(i) <= ch_current_dst(i) + (DATA_WIDTH/8);
                            ch_remaining(i) <= ch_remaining(i) - 1;
                            
                            if ch_remaining(i) = 1 then
                                ch_state(i) <= CH_COMPLETE;
                            else
                                case ch_mode(i*2+1 downto i*2) is
                                    when "00" =>  -- M2M
                                        ch_state(i) <= CH_READ_SETUP;
                                    when "10" =>  -- P2M
                                        ch_state(i) <= CH_IDLE;  -- Wait for next peripheral request
                                    when others =>
                                        ch_error(i) <= '1';
                                        ch_state(i) <= CH_IDLE;
                                end case;
                            end if;
                        end if;
                    
                    when CH_COMPLETE =>
                        ch_done(i) <= '1';
                        ch_irq(i) <= '1';
                        ch_busy(i) <= '0';
                        ch_state(i) <= CH_IDLE;
                    
                    when others =>
                        ch_state(i) <= CH_IDLE;
                end case;
            end if;
        end process;
        
        -- Channel request generation
        channel_request(i) <= '1' when (ch_state(i) = CH_READ_SETUP or ch_state(i) = CH_WRITE_SETUP) else '0';
        
        -- Peripheral interface
        periph_ack(i) <= '1' when (ch_state(i) = CH_IDLE and periph_req(i) = '1' and ch_mode(i*2+1 downto i*2) = "10") or
                                  (ch_state(i) = CH_READ_DATA and ch_mode(i*2+1 downto i*2) = "01" and arbiter_grant(i) = '1') else '0';
        
        periph_data_out((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= ch_data_buffer(i) when ch_state(i) = CH_READ_DATA and ch_mode(i*2+1 downto i*2) = "01" else (others => '0');
        
    end generate;
    
    -- Memory Interface Multiplexing
    process(current_channel, ch_current_src, ch_current_dst, ch_data_buffer, arbiter_grant)
    begin
        mux_mem_addr <= (others => '0');
        mux_mem_wdata <= (others => '0');
        mux_mem_we <= '0';
        mux_mem_re <= '0';
        
        for i in 0 to NUM_CHANNELS-1 loop
            if arbiter_grant(i) = '1' then
                case ch_state(i) is
                    when CH_READ_DATA =>
                        mux_mem_addr <= std_logic_vector(ch_current_src(i));
                        mux_mem_re <= '1';
                    when CH_WRITE_DATA =>
                        mux_mem_addr <= std_logic_vector(ch_current_dst(i));
                        mux_mem_wdata <= ch_data_buffer(i);
                        mux_mem_we <= '1';
                    when others =>
                        null;
                end case;
            end if;
        end loop;
    end process;
    
    -- Output assignments
    mem_addr <= mux_mem_addr;
    mem_wdata <= mux_mem_wdata;
    mem_we <= mux_mem_we;
    mem_re <= mux_mem_re;
    
end behavioral;
```

---

## 📊 **Scatter-Gather DMA**

### Advanced Scatter-Gather DMA Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity scatter_gather_dma is
    generic (
        ADDR_WIDTH : integer := 32;
        DATA_WIDTH : integer := 32;
        DESC_WIDTH : integer := 128  -- Descriptor width
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        
        -- Descriptor Chain Interface
        desc_base_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        desc_start  : in  std_logic;
        desc_enable : in  std_logic;
        
        -- Memory Interface
        mem_addr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        mem_wdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_rdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        mem_we      : out std_logic;
        mem_re      : out std_logic;
        mem_ready   : in  std_logic;
        mem_valid   : in  std_logic;
        
        -- Status and Control
        sg_busy     : out std_logic;
        sg_done     : out std_logic;
        sg_error    : out std_logic;
        sg_irq      : out std_logic;
        
        -- Debug
        current_desc_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        desc_count  : out std_logic_vector(15 downto 0)
    );
end scatter_gather_dma;

architecture behavioral of scatter_gather_dma is
    -- Descriptor format (128-bit):
    -- [31:0]   - Source Address
    -- [63:32]  - Destination Address  
    -- [79:64]  - Transfer Length
    -- [95:80]  - Control/Status
    -- [127:96] - Next Descriptor Address
    
    type sg_state_type is (SG_IDLE, FETCH_DESC, PARSE_DESC, TRANSFER_DATA, UPDATE_DESC, NEXT_DESC, SG_COMPLETE, SG_ERROR);
    signal sg_state : sg_state_type;
    
    -- Descriptor fields
    signal desc_src_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal desc_dst_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal desc_length : unsigned(15 downto 0);
    signal desc_control : std_logic_vector(15 downto 0);
    signal desc_next_addr : unsigned(ADDR_WIDTH-1 downto 0);
    
    -- Current descriptor processing
    signal current_desc : unsigned(ADDR_WIDTH-1 downto 0);
    signal desc_buffer : std_logic_vector(DESC_WIDTH-1 downto 0);
    signal desc_fetch_count : integer range 0 to 4;  -- 4 x 32-bit reads for 128-bit descriptor
    
    -- Transfer state
    signal transfer_src : unsigned(ADDR_WIDTH-1 downto 0);
    signal transfer_dst : unsigned(ADDR_WIDTH-1 downto 0);
    signal transfer_remaining : unsigned(15 downto 0);
    signal data_buffer : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Transfer sub-state
    type transfer_state_type is (T_READ_SETUP, T_READ_DATA, T_WRITE_SETUP, T_WRITE_DATA);
    signal transfer_state : transfer_state_type;
    
    signal descriptor_counter : unsigned(15 downto 0);
    
begin
    
    -- Main Scatter-Gather State Machine
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sg_state <= SG_IDLE;
            current_desc <= (others => '0');
            desc_buffer <= (others => '0');
            desc_fetch_count <= 0;
            descriptor_counter <= (others => '0');
            
            desc_src_addr <= (others => '0');
            desc_dst_addr <= (others => '0');
            desc_length <= (others => '0');
            desc_control <= (others => '0');
            desc_next_addr <= (others => '0');
            
            transfer_src <= (others => '0');
            transfer_dst <= (others => '0');
            transfer_remaining <= (others => '0');
            data_buffer <= (others => '0');
            transfer_state <= T_READ_SETUP;
            
            mem_addr <= (others => '0');
            mem_wdata <= (others => '0');
            mem_we <= '0';
            mem_re <= '0';
            
            sg_busy <= '0';
            sg_done <= '0';
            sg_error <= '0';
            sg_irq <= '0';
            
        elsif rising_edge(clk) then
            -- Default signal states
            mem_we <= '0';
            mem_re <= '0';
            sg_done <= '0';
            sg_irq <= '0';
            
            case sg_state is
                when SG_IDLE =>
                    sg_busy <= '0';
                    sg_error <= '0';
                    descriptor_counter <= (others => '0');
                    
                    if desc_start = '1' and desc_enable = '1' then
                        current_desc <= unsigned(desc_base_addr);
                        sg_busy <= '1';
                        sg_state <= FETCH_DESC;
                        desc_fetch_count <= 0;
                    end if;
                
                when FETCH_DESC =>
                    -- Fetch 128-bit descriptor in 4 x 32-bit reads
                    mem_addr <= std_logic_vector(current_desc + (desc_fetch_count * 4));
                    mem_re <= '1';
                    
                    if mem_valid = '1' then
                        -- Store descriptor data
                        case desc_fetch_count is
                            when 0 => desc_buffer(31 downto 0) <= mem_rdata;
                            when 1 => desc_buffer(63 downto 32) <= mem_rdata;
                            when 2 => desc_buffer(95 downto 64) <= mem_rdata;
                            when 3 => desc_buffer(127 downto 96) <= mem_rdata;
                            when others => null;
                        end case;
                        
                        if desc_fetch_count = 3 then
                            sg_state <= PARSE_DESC;
                        else
                            desc_fetch_count <= desc_fetch_count + 1;
                        end if;
                    end if;
                
                when PARSE_DESC =>
                    -- Parse descriptor fields
                    desc_src_addr <= unsigned(desc_buffer(31 downto 0));
                    desc_dst_addr <= unsigned(desc_buffer(63 downto 32));
                    desc_length <= unsigned(desc_buffer(79 downto 64));
                    desc_control <= desc_buffer(95 downto 80);
                    desc_next_addr <= unsigned(desc_buffer(127 downto 96));
                    
                    -- Initialize transfer parameters
                    transfer_src <= unsigned(desc_buffer(31 downto 0));
                    transfer_dst <= unsigned(desc_buffer(63 downto 32));
                    transfer_remaining <= unsigned(desc_buffer(79 downto 64));
                    transfer_state <= T_READ_SETUP;
                    
                    -- Check for valid descriptor
                    if unsigned(desc_buffer(79 downto 64)) = 0 then
                        sg_state <= SG_ERROR;  -- Invalid length
                    else
                        sg_state <= TRANSFER_DATA;
                    end if;
                
                when TRANSFER_DATA =>
                    case transfer_state is
                        when T_READ_SETUP =>
                            mem_addr <= std_logic_vector(transfer_src);
                            mem_re <= '1';
                            transfer_state <= T_READ_DATA;
                        
                        when T_READ_DATA =>
                            if mem_valid = '1' then
                                data_buffer <= mem_rdata;
                                transfer_src <= transfer_src + (DATA_WIDTH/8);
                                transfer_state <= T_WRITE_SETUP;
                            end if;
                        
                        when T_WRITE_SETUP =>
                            mem_addr <= std_logic_vector(transfer_dst);
                            mem_wdata <= data_buffer;
                            mem_we <= '1';
                            transfer_state <= T_WRITE_DATA;
                        
                        when T_WRITE_DATA =>
                            if mem_ready = '1' then
                                transfer_dst <= transfer_dst + (DATA_WIDTH/8);
                                transfer_remaining <= transfer_remaining - 1;
                                
                                if transfer_remaining = 1 then
                                    sg_state <= UPDATE_DESC;
                                else
                                    transfer_state <= T_READ_SETUP;
                                end if;
                            end if;
                    end case;
                
                when UPDATE_DESC =>
                    -- Update descriptor status (mark as completed)
                    mem_addr <= std_logic_vector(current_desc + 10);  -- Control/Status field offset
                    mem_wdata <= desc_control(31 downto 16) & x"0001";  -- Set completion bit
                    mem_we <= '1';
                    
                    if mem_ready = '1' then
                        descriptor_counter <= descriptor_counter + 1;
                        sg_state <= NEXT_DESC;
                    end if;
                
                when NEXT_DESC =>
                    -- Check for next descriptor
                    if desc_next_addr = 0 then
                        -- End of chain
                        sg_state <= SG_COMPLETE;
                    else
                        -- Continue with next descriptor
                        current_desc <= desc_next_addr;
                        sg_state <= FETCH_DESC;
                        desc_fetch_count <= 0;
                    end if;
                
                when SG_COMPLETE =>
                    sg_done <= '1';
                    sg_irq <= '1';
                    sg_busy <= '0';
                    sg_state <= SG_IDLE;
                
                when SG_ERROR =>
                    sg_error <= '1';
                    sg_irq <= '1';
                    sg_busy <= '0';
                    sg_state <= SG_IDLE;
                
                when others =>
                    sg_state <= SG_IDLE;
            end case;
        end if;
    end process;
    
    -- Debug outputs
    current_desc_addr <= std_logic_vector(current_desc);
    desc_count <= std_logic_vector(descriptor_counter);
    
end behavioral;
```

---

## 🚌 **AXI4 DMA Controller**

### AXI4 Master DMA Controller
```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4_dma_controller is
    generic (
        AXI_ADDR_WIDTH : integer := 32;
        AXI_DATA_WIDTH : integer := 64;
        AXI_ID_WIDTH : integer := 4;
        MAX_BURST_LEN : integer := 16
    );
    port (
        -- Clock and Reset
        axi_aclk    : in  std_logic;
        axi_aresetn : in  std_logic;
        
        -- DMA Control Interface
        dma_src_addr : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        dma_dst_addr : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        dma_length  : in  std_logic_vector(23 downto 0);  -- Transfer length in bytes
        dma_start   : in  std_logic;
        dma_enable  : in  std_logic;
        
        -- AXI4 Master Read Address Channel
        m_axi_arid    : out std_logic_vector(AXI_ID_WIDTH-1 downto 0);
        m_axi_araddr  : out std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        m_axi_arlen   : out std_logic_vector(7 downto 0);
        m_axi_arsize  : out std_logic_vector(2 downto 0);
        m_axi_arburst : out std_logic_vector(1 downto 0);
        m_axi_arlock  : out std_logic;
        m_axi_arcache : out std_logic_vector(3 downto 0);
        m_axi_arprot  : out std_logic_vector(2 downto 0);
        m_axi_arqos   : out std_logic_vector(3 downto 0);
        m_axi_arvalid : out std_logic;
        m_axi_arready : in  std_logic;
        
        -- AXI4 Master Read Data Channel
        m_axi_rid     : in  std_logic_vector(AXI_ID_WIDTH-1 downto 0);
        m_axi_rdata   : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        m_axi_rresp   : in  std_logic_vector(1 downto 0);
        m_axi_rlast   : in  std_logic;
        m_axi_rvalid  : in  std_logic;
        m_axi_rready  : out std_logic;
        
        -- AXI4 Master Write Address Channel
        m_axi_awid    : out std_logic_vector(AXI_ID_WIDTH-1 downto 0);
        m_axi_awaddr  : out std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        m_axi_awlen   : out std_logic_vector(7 downto 0);
        m_axi_awsize  : out std_logic_vector(2 downto 0);
        m_axi_awburst : out std_logic_vector(1 downto 0);
        m_axi_awlock  : out std_logic;
        m_axi_awcache : out std_logic_vector(3 downto 0);
        m_axi_awprot  : out std_logic_vector(2 downto 0);
        m_axi_awqos   : out std_logic_vector(3 downto 0);
        m_axi_awvalid : out std_logic;
        m_axi_awready : in  std_logic;
        
        -- AXI4 Master Write Data Channel
        m_axi_wdata   : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        m_axi_wstrb   : out std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
        m_axi_wlast   : out std_logic;
        m_axi_wvalid  : out std_logic;
        m_axi_wready  : in  std_logic;
        
        -- AXI4 Master Write Response Channel
        m_axi_bid     : in  std_logic_vector(AXI_ID_WIDTH-1 downto 0);
        m_axi_bresp   : in  std_logic_vector(1 downto 0);
        m_axi_bvalid  : in  std_logic;
        m_axi_bready  : out std_logic;
        
        -- Status
        dma_busy      : out std_logic;
        dma_done      : out std_logic;
        dma_error     : out std_logic;
        
        -- Performance counters
        read_transactions  : out std_logic_vector(15 downto 0);
        write_transactions : out std_logic_vector(15 downto 0)
    );
end axi4_dma_controller;

architecture behavioral of axi4_dma_controller is
    -- State machines
    type read_state_type is (R_IDLE, R_ADDR, R_DATA, R_COMPLETE);
    type write_state_type is (W_IDLE, W_ADDR, W_DATA, W_RESP, W_COMPLETE);
    
    signal read_state : read_state_type;
    signal write_state : write_state_type;
    
    -- Address and length calculations
    signal src_addr_reg : unsigned(AXI_ADDR_WIDTH-1 downto 0);
    signal dst_addr_reg : unsigned(AXI_ADDR_WIDTH-1 downto 0);
    signal remaining_bytes : unsigned(23 downto 0);
    signal current_burst_len : unsigned(7 downto 0);
    
    -- Data FIFO for read-to-write buffering
    type data_fifo_type is array (0 to 15) of std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    signal data_fifo : data_fifo_type;
    signal fifo_wr_ptr : unsigned(3 downto 0);
    signal fifo_rd_ptr : unsigned(3 downto 0);
    signal fifo_count : unsigned(4 downto 0);
    signal fifo_full : std_logic;
    signal fifo_empty : std_logic;
    
    -- Burst management
    signal read_burst_count : unsigned(7 downto 0);
    signal write_burst_count : unsigned(7 downto 0);
    
    -- Performance counters
    signal read_txn_count : unsigned(15 downto 0);
    signal write_txn_count : unsigned(15 downto 0);
    
    -- Constants
    constant BYTES_PER_BEAT : integer := AXI_DATA_WIDTH / 8;
    
begin
    
    -- FIFO status
    fifo_full <= '1' when fifo_count = 16 else '0';
    fifo_empty <= '1' when fifo_count = 0 else '0';
    
    -- Calculate burst length based on remaining data and alignment
    process(remaining_bytes, src_addr_reg, dst_addr_reg)
        variable max_burst_bytes : unsigned(23 downto 0);
        variable addr_aligned_burst : unsigned(7 downto 0);
    begin
        -- Maximum burst size in bytes
        max_burst_bytes := to_unsigned(MAX_BURST_LEN * BYTES_PER_BEAT, 24);
        
        -- Calculate burst length (limited by remaining data and max burst)
        if remaining_bytes >= max_burst_bytes then
            current_burst_len <= to_unsigned(MAX_BURST_LEN - 1, 8);  -- AXI burst length is N-1
        else
            current_burst_len <= resize((remaining_bytes / BYTES_PER_BEAT) - 1, 8);
        end if;
    end process;
    
    -- Read State Machine
    process(axi_aclk, axi_aresetn)
    begin
        if axi_aresetn = '0' then
            read_state <= R_IDLE;
            src_addr_reg <= (others => '0');
            remaining_bytes <= (others => '0');
            read_burst_count <= (others => '0');
            read_txn_count <= (others => '0');
            
            m_axi_arid <= (others => '0');
            m_axi_araddr <= (others => '0');
            m_axi_arlen <= (others => '0');
            m_axi_arsize <= "011";  -- 8 bytes (64-bit)
            m_axi_arburst <= "01";  -- INCR
            m_axi_arlock <= '0';
            m_axi_arcache <= "0011";  -- Normal, non-cacheable, bufferable
            m_axi_arprot <= "000";
            m_axi_arqos <= "0000";
            m_axi_arvalid <= '0';
            m_axi_rready <= '0';
            
        elsif rising_edge(axi_aclk) then
            case read_state is
                when R_IDLE =>
                    m_axi_arvalid <= '0';
                    m_axi_rready <= '0';
                    
                    if dma_start = '1' and dma_enable = '1' then
                        src_addr_reg <= unsigned(dma_src_addr);
                        remaining_bytes <= unsigned(dma_length);
                        read_state <= R_ADDR;
                    end if;
                
                when R_ADDR =>
                    if not fifo_full and remaining_bytes > 0 then
                        m_axi_arid <= "0001";
                        m_axi_araddr <= std_logic_vector(src_addr_reg);
                        m_axi_arlen <= std_logic_vector(current_burst_len);
                        m_axi_arvalid <= '1';
                        
                        if m_axi_arready = '1' then
                            read_burst_count <= current_burst_len + 1;
                            read_state <= R_DATA;
                            read_txn_count <= read_txn_count + 1;
                        end if;
                    end if;
                
                when R_DATA =>
                    m_axi_arvalid <= '0';
                    m_axi_rready <= '1';
                    
                    if m_axi_rvalid = '1' then
                        -- Store data in FIFO
                        data_fifo(to_integer(fifo_wr_ptr)) <= m_axi_rdata;
                        fifo_wr_ptr <= fifo_wr_ptr + 1;
                        fifo_count <= fifo_count + 1;
                        
                        read_burst_count <= read_burst_count - 1;
                        src_addr_reg <= src_addr_reg + BYTES_PER_BEAT;
                        remaining_bytes <= remaining_bytes - BYTES_PER_BEAT;
                        
                        if m_axi_rlast = '1' then
                            if remaining_bytes <= BYTES_PER_BEAT then
                                read_state <= R_COMPLETE;
                            else
                                read_state <= R_ADDR;
                            end if;
                        end if;
                    end if;
                
                when R_COMPLETE =>
                    m_axi_rready <= '0';
                    -- Stay in complete state until reset
                
                when others =>
                    read_state <= R_IDLE;
            end case;
        end if;
    end process;
    
    -- Write State Machine
    process(axi_aclk, axi_aresetn)
        variable write_bytes_remaining : unsigned(23 downto 0);
    begin
        if axi_aresetn = '0' then
            write_state <= W_IDLE;
            dst_addr_reg <= (others => '0');
            write_bytes_remaining := (others => '0');
            write_burst_count <= (others => '0');
            write_txn_count <= (others => '0');
            
            m_axi_awid <= (others => '0');
            m_axi_awaddr <= (others => '0');
            m_axi_awlen <= (others => '0');
            m_axi_awsize <= "011";  -- 8 bytes
            m_axi_awburst <= "01";  -- INCR
            m_axi_awlock <= '0';
            m_axi_awcache <= "0011";
            m_axi_awprot <= "000";
            m_axi_awqos <= "0000";
            m_axi_awvalid <= '0';
            
            m_axi_wdata <= (others => '0');
            m_axi_wstrb <= (others => '1');
            m_axi_wlast <= '0';
            m_axi_wvalid <= '0';
            m_axi_bready <= '0';
            
        elsif rising_edge(axi_aclk) then
            case write_state is
                when W_IDLE =>
                    m_axi_awvalid <= '0';
                    m_axi_wvalid <= '0';
                    m_axi_bready <= '0';
                    
                    if dma_start = '1' and dma_enable = '1' then
                        dst_addr_reg <= unsigned(dma_dst_addr);
                        write_bytes_remaining := unsigned(dma_length);
                        write_state <= W_ADDR;
                    end if;
                
                when W_ADDR =>
                    if not fifo_empty and write_bytes_remaining > 0 then
                        m_axi_awid <= "0001";
                        m_axi_awaddr <= std_logic_vector(dst_addr_reg);
                        m_axi_awlen <= std_logic_vector(current_burst_len);
                        m_axi_awvalid <= '1';
                        
                        if m_axi_awready = '1' then
                            write_burst_count <= current_burst_len + 1;
                            write_state <= W_DATA;
                            write_txn_count <= write_txn_count + 1;
                        end if;
                    end if;
                
                when W_DATA =>
                    m_axi_awvalid <= '0';
                    
                    if not fifo_empty then
                        m_axi_wdata <= data_fifo(to_integer(fifo_rd_ptr));
                        m_axi_wvalid <= '1';
                        
                        if write_burst_count = 1 then
                            m_axi_wlast <= '1';
                        else
                            m_axi_wlast <= '0';
                        end if;
                        
                        if m_axi_wready = '1' then
                            fifo_rd_ptr <= fifo_rd_ptr + 1;
                            fifo_count <= fifo_count - 1;
                            write_burst_count <= write_burst_count - 1;
                            dst_addr_reg <= dst_addr_reg + BYTES_PER_BEAT;
                            write_bytes_remaining := write_bytes_remaining - BYTES_PER_BEAT;
                            
                            if write_burst_count = 1 then
                                write_state <= W_RESP;
                            end if;
                        end if;
                    end if;
                
                when W_RESP =>
                    m_axi_wvalid <= '0';
                    m_axi_wlast <= '0';
                    m_axi_bready <= '1';
                    
                    if m_axi_bvalid = '1' then
                        if write_bytes_remaining = 0 then
                            write_state <= W_COMPLETE;
                        else
                            write_state <= W_ADDR;
                        end if;
                    end if;
                
                when W_COMPLETE =>
                    m_axi_bready <= '0';
                    -- Stay in complete state until reset
                
                when others =>
                    write_state <= W_IDLE;
            end case;
        end if;
    end process;
    
    -- Status outputs
    dma_busy <= '1' when (read_state /= R_IDLE and read_state /= R_COMPLETE) or 
                         (write_state /= W_IDLE and write_state /= W_COMPLETE) else '0';
    
    dma_done <= '1' when read_state = R_COMPLETE and write_state = W_COMPLETE else '0';
    
    dma_error <= '1' when (m_axi_rvalid = '1' and m_axi_rresp /= "00") or
                          (m_axi_bvalid = '1' and m_axi_bresp /= "00") else '0';
    
    -- Performance counter outputs
    read_transactions <= std_logic_vector(read_txn_count);
    write_transactions <= std_logic_vector(write_txn_count);
    
end behavioral;
```