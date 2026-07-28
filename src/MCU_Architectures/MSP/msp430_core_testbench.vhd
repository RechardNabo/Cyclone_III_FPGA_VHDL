-- ================================================================================
-- msp430_core_testbench : Testbench for MSP430 soft core
-- ================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity msp430_core_tb is
end entity msp430_core_tb;

architecture sim of msp430_core_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal mem_addr   : std_logic_vector(15 downto 0);
    signal mem_dout   : std_logic_vector(15 downto 0);
    signal mem_din    : std_logic_vector(15 downto 0);
    signal mem_we     : std_logic;
    signal mem_re     : std_logic;
    signal port1_out  : std_logic_vector(7 downto 0);
    signal port2_out  : std_logic_vector(7 downto 0);
    signal port1_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal port2_in   : std_logic_vector(7 downto 0) := (others => '0');
    signal p1dir_out  : std_logic_vector(7 downto 0);
    signal p2dir_out  : std_logic_vector(7 downto 0);
    signal irq        : std_logic_vector(7 downto 0) := (others => '0');
    signal irq_out    : std_logic;
    signal running    : std_logic;
    signal debug_r4   : std_logic_vector(15 downto 0);
    signal debug_r5   : std_logic_vector(15 downto 0);
    signal debug_r6   : std_logic_vector(15 downto 0);

    -- Unified memory: 4K x 16
    type mem_array is array(0 to 4095) of std_logic_vector(15 downto 0);

    -- Instruction encodings (precomputed):
    -- MOV #1, R4: 0100 0011 0010 0100 = 0x4324
    -- MOV #2, R5: 0100 0011 0011 0101 = 0x4335
    -- ADD R5, R4: 0101 0101 0000 0100 = 0x5504
    -- MOV R4, R6: 0100 0100 0000 0110 = 0x4406
    -- MOV #0xFF, R7: 0100 0000 0011 0111 = 0x4037
    -- 0x00FF: 0x00FF
    -- MOV R7, &P1DIR: 0100 0111 1000 0010 = 0x4782
    -- 0x0022: 0x0022
    -- MOV #0xAA, R8: 0100 0000 0011 1000 = 0x4038
    -- 0x00AA: 0x00AA
    -- MOV R8, &P1OUT: 0100 1000 1000 0010 = 0x4882
    -- 0x0021: 0x0021
    -- JMP -1: 001 111 1111111111 = 0x3FFF
    signal mem : mem_array := (
        0  => x"4324",  -- MOV #1, R4
        1  => x"4335",  -- MOV #2, R5
        2  => x"5504",  -- ADD R5, R4
        3  => x"4406",  -- MOV R4, R6
        4  => x"4037",  -- MOV #0xFF, R7
        5  => x"00FF",  -- immediate value
        6  => x"4782",  -- MOV R7, &P1DIR
        7  => x"0022",  -- P1DIR address
        8  => x"4038",  -- MOV #0xAA, R8
        9  => x"00AA",  -- immediate value
        10 => x"4882",  -- MOV R8, &P1OUT
        11 => x"0021",  -- P1OUT address
        12 => x"3FFF",  -- JMP -1
        others => (others => '0')
    );

    signal sim_done : boolean := false;

begin

    dut : entity work.msp430_core
        generic map (
            MEM_SIZE => 4096
        )
        port map (
            clk        => clk,
            reset      => reset,
            mem_addr   => mem_addr,
            mem_dout   => mem_dout,
            mem_din    => mem_din,
            mem_we     => mem_we,
            mem_re     => mem_re,
            port1_out  => port1_out,
            port2_out  => port2_out,
            port1_in   => port1_in,
            port2_in   => port2_in,
            p1dir_out  => p1dir_out,
            p2dir_out  => p2dir_out,
            irq        => irq,
            irq_out    => irq_out,
            running    => running,
            debug_r4   => debug_r4,
            debug_r5   => debug_r5,
            debug_r6   => debug_r6
        );

    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Memory model: word-addressed (MSP430 uses byte addresses, we use word index)
    -- mem_addr is byte address; divide by 2 for word index
    -- Combinational read
    mem_din <= mem(to_integer(unsigned(mem_addr(11 downto 1))));

    -- Write-back process (only drives mem during write cycles)
    mem_proc : process(clk)
    begin
        if rising_edge(clk) then
            if mem_we = '1' then
                mem(to_integer(unsigned(mem_addr(11 downto 1)))) <= mem_dout;
            end if;
        end if;
    end process;

    stim_proc : process
        -- MSP430 instruction encoders (16-bit)
        -- Format I (dual-operand): [15:12]=op [11:8]=src [7]=Ad [6]=B/W [5:4]=As [3:0]=dst
        -- Format II (single): [15:12]=0001 [11:8]=ext [7]=B/W [5:4]=Ad [3:0]=dst
        -- Format III (jump): [15:13]=001 [12:10]=cond [9:0]=offset

        -- Addressing modes (As/Ad):
        --   00 = Register (Rn)
        --   01 = Indexed (X(Rn)) or Symbolic/Absolute for R0/R2
        --   10 = Indirect (@Rn)
        --   11 = Indirect Autoincrement (@Rn+) or Immediate (#N) for R0

        function mov_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- MOV Rsrc, Rdst: 0100 src 0000 dst (As=00, Ad=0, B/W=0)
            return "0100" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        function mov_imm(dst : integer; imm : integer) return std_logic_vector is
        begin
            -- MOV #imm, Rdst: 0100 0000 0011 dst + imm word (src=R0/PC, As=11)
            -- Bits [7:4] = Ad=0, B/W=0, As=11
            return "0100" & "0000" & "0011" & std_logic_vector(to_unsigned(dst, 4));
        end function;

        function add_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- ADD Rsrc, Rdst: 0101 src 0000 dst
            return "0101" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        function add_imm(dst : integer; imm : integer) return std_logic_vector is
        begin
            -- ADD #imm, Rdst: 0101 0000 00 11 dst + imm
            return "0101" & "0000" & "0011" & std_logic_vector(to_unsigned(dst, 4));
        end function;

        function sub_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- SUB Rsrc, Rdst: 1000 src 0000 dst
            return "1000" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        function mov_const(dst : integer; const_val : integer) return std_logic_vector is
        begin
            -- Use constant generator: MOV #N, Rdst
            -- Bits [7:4] = Ad(1) & B/W(1) & As(2)
            -- Ad=0 (register dst), B/W=0 (word)
            if const_val = 1 then
                -- R3 As=10 = +1
                return "0100" & "0011" & "0010" & std_logic_vector(to_unsigned(dst, 4));
            elsif const_val = 2 then
                -- R3 As=11 = +2
                return "0100" & "0011" & "0011" & std_logic_vector(to_unsigned(dst, 4));
            elsif const_val = -1 or const_val = 16#FFFF# then
                -- R3 As=00 = -1
                return "0100" & "0011" & "0000" & std_logic_vector(to_unsigned(dst, 4));
            else
                -- R3 As=01 = 0
                return "0100" & "0011" & "0001" & std_logic_vector(to_unsigned(dst, 4));
            end if;
        end function;

        function cmp_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- CMP Rsrc, Rdst: 1001 src 0000 dst
            return "1001" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        function jne(offset : integer) return std_logic_vector is
        begin
            -- JNE: 001 000 offset (10-bit signed)
            return "001" & "000" & std_logic_vector(to_signed(offset, 10));
        end function;

        function jmp(offset : integer) return std_logic_vector is
        begin
            -- JMP: 001 111 offset (10-bit signed)
            return "001" & "111" & std_logic_vector(to_signed(offset, 10));
        end function;

        function bis_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- BIS Rsrc, Rdst (OR): 1101 src 0000 dst
            return "1101" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        function bic_rr(dst : integer; src : integer) return std_logic_vector is
        begin
            -- BIC Rsrc, Rdst (AND NOT): 1100 src 0000 dst
            return "1100" & std_logic_vector(to_unsigned(src, 4)) & "0000" &
                   std_logic_vector(to_unsigned(dst, 4));
        end function;

        -- I/O addresses
        constant P1OUT_ADDR : integer := 16#0021#;
        constant P1DIR_ADDR : integer := 16#0022#;

        variable r4_val : std_logic_vector(15 downto 0);
        variable r5_val : std_logic_vector(15 downto 0);
        variable r6_val : std_logic_vector(15 downto 0);
        variable sram_200 : std_logic_vector(15 downto 0);
    begin
        -- Memory is initialized in the signal declaration

        -- Reset
        reset <= '1';
        wait for CLK_PERIOD * 4;
        reset <= '0';

        -- Wait for program to complete
        wait for CLK_PERIOD * 200;

        -- Verify register values
        assert debug_r4 = x"0003"
            report "FAIL: R4 = 0x" & to_hstring(debug_r4) & ", expected 0x0003"
            severity error;

        assert debug_r5 = x"0002"
            report "FAIL: R5 = 0x" & to_hstring(debug_r5) & ", expected 0x0002"
            severity error;

        assert debug_r6 = x"0003"
            report "FAIL: R6 = 0x" & to_hstring(debug_r6) & ", expected 0x0003"
            severity error;

        -- Verify I/O
        assert p1dir_out = x"FF"
            report "FAIL: P1DIR = 0x" & to_hstring(p1dir_out) & ", expected 0xFF"
            severity error;

        assert port1_out = x"AA"
            report "FAIL: P1OUT = 0x" & to_hstring(port1_out) & ", expected 0xAA"
            severity error;

        report "MSP430 Testbench complete" severity note;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
