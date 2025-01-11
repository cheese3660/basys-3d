library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity ScanlineTest is

end ScanlineTest;

architecture TB of ScanlineTest is
    signal y: unsigned(6 downto 0);
    signal x0: signed(7 downto 0);
    signal x1: signed(7 downto 0);
    signal color: std_logic_vector(4 downto 0);
    signal drawLine: std_logic;

    signal plotEn: std_logic;
    signal pixelInfo: PixelEntry;
    
    signal clock: std_logic;
    signal reset: std_logic;
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

    SCANLINE_FEEDER: process
    begin
        wait until rising_edge(clock);
        y <= to_unsigned(20,7);
        x0 <= to_signed(15, 8);
        x1 <= to_signed(120, 8);
        color <= "01111";
        drawLine <= '1';
        wait until rising_edge(clock);
        y <= to_unsigned(40,7);
        x0 <= to_signed(-5, 8);
        x1 <= to_signed(120, 8);
        color <= "11100";
        drawLine <= '1';
        wait until rising_edge(clock);
        y <= to_unsigned(60,7);
        x0 <= to_signed(60, 8);
        x1 <= to_signed(30, 8);
        color <= "00111";
        drawLine <= '1';
        wait until rising_edge(clock);
        drawLine <= '0';
        wait;
    end process;
    
    SCANLINE_GENERATOR: ScanlinePipeline port map(
        clock => clock,
        reset => reset,

        scanlineY => y,
        scanlineX0 => x0,
        scanlineX1 => x1,
        scanlineZ0 => (others => '0'),
        scanlineZ1 => (others => '0'),
        scanlineColor => color,
        scanlinePlotEn => drawLine,

        pixelInfo => pixelInfo,
        plotEn => plotEn
    );
    
    SCANLINE_REPORTER: process
    begin
        loop
            wait until rising_edge(clock);
            if plotEn then
                ReportPixel(pixelInfo);
            end if;
        end loop;
    end process;
end TB;