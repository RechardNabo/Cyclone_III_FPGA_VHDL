library ieee;
use ieee.std_logic_1164.all;

entity Basic_Logic_Top is
    port (
        -- Inputs
        A, B : in  std_logic;
        
        -- Basic Logic Gate Outputs
        and_out    : out std_logic;
        or_out     : out std_logic;
        nand_out   : out std_logic;
        nor_out    : out std_logic;
        xor_out    : out std_logic;
        xnor_out   : out std_logic;
        inv_out    : out std_logic;
        
        -- Additional control signals if needed
        driver_in  : in  std_logic;
        driver_out : out std_logic
    );
end entity Basic_Logic_Top;

architecture Structural of Basic_Logic_Top is
    -- Component declarations
    component AND_gate is
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component OR_gate is
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component NAND_gate is
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component NOR_gate is
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component XOR_gate is
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component XNOR_L is  -- Note: Using actual entity name from file
        port (
            x, y : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component Inverter is
        port (
            x    : in  std_logic;
            f    : out std_logic
        );
    end component;
    
    component Driver is
        port (
            x    : in  std_logic;
            f    : out std_logic
        );
    end component;


begin
    -- Component instantiations
    AND_inst: AND_gate
        port map (
            x => A,
            y => B,
            f => and_out
        );
        
    OR_inst: OR_gate
        port map (
            x => A,
            y => B,
            f => or_out
        );
        
    NAND_inst: NAND_gate
        port map (
            x => A,
            y => B,
            f => nand_out
        );
        
    NOR_inst: NOR_gate
        port map (
            x => A,
            y => B,
            f => nor_out
        );
        
    XOR_inst: XOR_gate
        port map (
            x => A,
            y => B,
            f => xor_out
        );
        
    XNOR_inst: XNOR_L
        port map (
            x => A,
            y => B,
            f => xnor_out
        );
        
    INV_inst: Inverter
        port map (
            x => A,
            f => inv_out
        );
        
    DRV_inst: Driver
        port map (
            x => driver_in,
            f => driver_out
        );

end architecture Structural;
