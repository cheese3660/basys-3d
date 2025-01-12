library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity WrapperTest is
end WrapperTest;

architecture TB of WrapperTest is

    component Basys3Wrapper is
        port (
            clk: in STD_LOGIC;
            btnC: in STD_LOGIC; -- reset
            btnD: in STD_LOGIC;
            sw: in STD_LOGIC_VECTOR(15 downto 0);
    
            vgaRed: out std_logic_vector(3 downto 0);
            vgaGreen: out std_logic_vector(3 downto 0);
            vgaBlue: out std_logic_vector(3 downto 0);
    
            led: out std_logic_vector(15 downto 0);
            Hsync: out std_logic;
            Vsync: out std_logic;
    
            seg: out std_logic_vector(6 downto 0);
            an: out std_logic_vector(3 downto 0)
        );
    end component;

    signal clock: std_logic;
    signal reset: std_logic;

    signal vgaRed: std_logic_vector(3 downto 0);
    signal vgaGreen: std_logic_vector(3 downto 0);
    signal vgaBlue: std_logic_vector(3 downto 0);

    signal HSync: std_logic;
    signal VSync: std_logic;
begin
    
    CLOCK_RESET: process
    begin
        clock <= '0';
        reset <= '1';
        wait for 10 ns;
        reset <= '0';
        loop
            clock <= '0';
            wait for 5 ns;
            clock <= '1';
            wait for 5 ns;
        end loop;
    end process;

    UUT: Basys3Wrapper port map(
            clk => clock,
            btnC => reset,
            btnD => '0',
            sw => (others => '0'),

            vgaRed => vgaRed,
            vgaGreen => vgaGreen,
            vgaBlue => vgaBlue,

            HSync => HSync,
            VSync => VSync
    );
end TB;
