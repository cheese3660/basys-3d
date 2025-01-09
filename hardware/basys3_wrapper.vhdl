library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity Basys3Wrapper is
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
        Vsync: out std_logic
    );
end Basys3Wrapper;

architecture Wrapper of Basys3Wrapper is
    
    signal info: PixelEntry;
begin

    DRIVER: VgaDriver port map(
        clock => clk,
        reset => btnC,

        red => vgaRed,
        green => vgaGreen,
        blue => vgaBlue,
        hSync => Hsync,
        vSync => Vsync
    );

    PLOTTER: UpperHalfPlotter port map(
        clock => clk,
        reset => btnC,

        xSlope1 => signed(sw),
        zSlope1 => signed(not sw),
        xSlope2 => signed(sw),
        zSlope2 => signed(not sw),
        minX => signed(sw(7 downto 0)),
        maxX => signed(sw(15 downto 8)),
        startX => signed(sw),
        startZ => signed(not sw),
        startY => signed(sw(11 downto 4)),
        endY => signed(sw(15 downto 8)),
        trigColor => sw(15 downto 11),
        beginPlotEn => btnD,
        
        pixelInfo => info
    );
    
    led <= std_logic_vector(info.z);

end Wrapper;