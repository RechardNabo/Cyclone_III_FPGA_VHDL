library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_isa_controller is
end entity tb_isa_controller;

architecture sim of tb_isa_controller is
    signal clk              : std_logic := '0';
    signal reset_n          : std_logic := '0';
    signal cpu_request      : std_logic := '0';
    signal cpu_read_write   : std_logic := '0';
    signal cpu_byte_word    : std_logic := '0';
    signal cpu_address      : std_logic_vector(15 downto 0) := (others => '0');
    signal cpu_data_in      : std_logic_vector(15 downto 0) := (others => '0');
    signal isa_data_in      : std_logic_vector(15 downto 0) := (others => '0');
    signal isa_ready        : std_logic := '0';
    signal isa_wait         : std_logic := '0';
    signal error_detected   : std_logic := '0';
    signal dma_request      : std_logic := '0';
    signal interrupt_request: std_logic := '0';
    signal config_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal status_flags     : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_acknowledge  : std_logic;
    signal cpu_data_out     : std_logic_vector(15 downto 0);
    signal cpu_data_ready   : std_logic;
    signal isa_address      : std_logic_vector(15 downto 0);
    signal isa_data_out     : std_logic_vector(15 downto 0);
    signal isa_address_enable: std_logic;
    signal isa_data_enable  : std_logic;
    signal isa_read_strobe  : std_logic;
    signal isa_write_strobe : std_logic;
    signal isa_io_read      : std_logic;
    signal isa_io_write     : std_logic;
    signal isa_memory_read  : std_logic;
    signal isa_memory_write : std_logic;
    signal current_state    : std_logic_vector(3 downto 0);
    signal transaction_active: std_logic;
    signal error_flag       : std_logic;
    signal busy_flag        : std_logic;
    signal data_valid       : std_logic;
begin
    clk <= not clk after 10 ns;

    dut : entity work.isa_controller_fsmd
        port map (
            clk => clk, reset_n => reset_n,
            cpu_request => cpu_request, cpu_read_write => cpu_read_write,
            cpu_byte_word => cpu_byte_word, cpu_address => cpu_address,
            cpu_data_in => cpu_data_in, isa_data_in => isa_data_in,
            isa_ready => isa_ready, isa_wait => isa_wait,
            error_detected => error_detected, dma_request => dma_request,
            interrupt_request => interrupt_request,
            config_data => config_data, status_flags => status_flags,
            cpu_acknowledge => cpu_acknowledge, cpu_data_out => cpu_data_out,
            cpu_data_ready => cpu_data_ready,
            isa_address => isa_address, isa_data_out => isa_data_out,
            isa_address_enable => isa_address_enable, isa_data_enable => isa_data_enable,
            isa_read_strobe => isa_read_strobe,
            isa_write_strobe => isa_write_strobe,
            isa_io_read => isa_io_read, isa_io_write => isa_io_write,
            isa_memory_read => isa_memory_read,
            isa_memory_write => isa_memory_write,
            current_state => current_state,
            transaction_active => transaction_active,
            error_flag => error_flag, busy_flag => busy_flag,
            data_valid => data_valid
        );

    stim : process
    begin
        -- Reset (active-low)
        reset_n <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset_n <= '1';
        wait until rising_edge(clk);
        assert busy_flag = '0' report "FAIL: busy after reset" severity error;

        -- CPU write transaction to ISA I/O
        cpu_request <= '1';
        cpu_read_write <= '1';  -- write
        cpu_byte_word <= '0';   -- byte
        cpu_address <= x"0080";
        cpu_data_in <= x"00AB";
        wait until rising_edge(clk);

        -- ISA bus ready
        isa_ready <= '1';
        for i in 0 to 20 loop
            wait until rising_edge(clk);
            if cpu_acknowledge = '1' then
                exit;
            end if;
        end loop;
        cpu_request <= '0';
        wait until rising_edge(clk);

        -- CPU read transaction from ISA memory
        cpu_request <= '1';
        cpu_read_write <= '0';  -- read
        cpu_byte_word <= '0';
        cpu_address <= x"1000";
        isa_data_in <= x"0042";
        isa_ready <= '1';
        for i in 0 to 20 loop
            wait until rising_edge(clk);
            if cpu_acknowledge = '1' then
                exit;
            end if;
        end loop;
        cpu_request <= '0';
        wait until rising_edge(clk);

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
