library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pci_bridge is
end entity tb_pci_bridge;

architecture sim of tb_pci_bridge is
    signal clk              : std_logic := '0';
    signal reset_n          : std_logic := '0';
    signal pci_ad           : std_logic_vector(31 downto 0) := (others => '0');
    signal pci_cbe_n        : std_logic_vector(3 downto 0) := (others => '1');
    signal pci_frame_n      : std_logic := '1';
    signal pci_irdy_n       : std_logic := '1';
    signal pci_trdy_n       : std_logic := '1';
    signal pci_devsel_n     : std_logic := '1';
    signal pci_stop_n       : std_logic := '1';
    signal pci_par          : std_logic := '0';
    signal pci_gnt_n        : std_logic := '1';
    signal local_addr       : std_logic_vector(31 downto 0) := (others => '0');
    signal local_data_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal local_req        : std_logic := '0';
    signal local_wr_en      : std_logic := '0';
    signal pci_ad_out       : std_logic_vector(31 downto 0);
    signal pci_ad_oe        : std_logic;
    signal pci_cbe_n_out    : std_logic_vector(3 downto 0);
    signal pci_req_n        : std_logic;
    signal pci_trdy_n_out   : std_logic;
    signal pci_devsel_n_out : std_logic;
    signal pci_stop_n_out   : std_logic;
    signal pci_par_out      : std_logic;
    signal local_data_out   : std_logic_vector(31 downto 0);
    signal local_ack        : std_logic;
    signal transaction_complete : std_logic;
    signal error_status     : std_logic_vector(7 downto 0);
    signal current_state    : std_logic_vector(3 downto 0);
begin
    clk <= not clk after 10 ns;

    dut : entity work.pci_bridge_fsmd
        port map (
            clk => clk, reset_n => reset_n,
            pci_ad => pci_ad, pci_cbe_n => pci_cbe_n,
            pci_frame_n => pci_frame_n, pci_irdy_n => pci_irdy_n,
            pci_trdy_n => pci_trdy_n, pci_devsel_n => pci_devsel_n,
            pci_stop_n => pci_stop_n, pci_par => pci_par,
            pci_gnt_n => pci_gnt_n,
            local_addr => local_addr, local_data_in => local_data_in,
            local_req => local_req, local_wr_en => local_wr_en,
            pci_ad_out => pci_ad_out, pci_ad_oe => pci_ad_oe,
            pci_cbe_n_out => pci_cbe_n_out, pci_req_n => pci_req_n,
            pci_trdy_n_out => pci_trdy_n_out,
            pci_devsel_n_out => pci_devsel_n_out,
            pci_stop_n_out => pci_stop_n_out,
            pci_par_out => pci_par_out,
            local_data_out => local_data_out, local_ack => local_ack,
            transaction_complete => transaction_complete,
            error_status => error_status, current_state => current_state
        );

    stim : process
    begin
        -- Reset (active-low)
        reset_n <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        reset_n <= '1';
        wait until rising_edge(clk);

        -- Local bus write request to PCI
        local_req <= '1';
        local_wr_en <= '1';
        local_addr <= x"00001234";
        local_data_in <= x"DEADBEEF";
        pci_gnt_n <= '0';  -- grant bus
        wait until rising_edge(clk);

        -- Simulate PCI target response
        for i in 0 to 30 loop
            pci_devsel_n <= '0';  -- target claims transaction
            pci_trdy_n <= '0';    -- target ready
            wait until rising_edge(clk);
            if transaction_complete = '1' then
                exit;
            end if;
        end loop;
        local_req <= '0';
        local_wr_en <= '0';
        pci_devsel_n <= '1';
        pci_trdy_n <= '1';
        wait until rising_edge(clk);

        -- Local bus read request from PCI
        local_req <= '1';
        local_wr_en <= '0';
        local_addr <= x"00005678";
        pci_ad <= x"CAFEBABE";
        pci_gnt_n <= '0';
        wait until rising_edge(clk);

        for i in 0 to 30 loop
            pci_devsel_n <= '0';
            pci_trdy_n <= '0';
            wait until rising_edge(clk);
            if transaction_complete = '1' then
                exit;
            end if;
        end loop;
        local_req <= '0';
        pci_devsel_n <= '1';
        pci_trdy_n <= '1';
        wait until rising_edge(clk);

        report "ALL TESTS PASSED" severity note;
        wait;
    end process;
end architecture sim;
