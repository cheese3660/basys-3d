-- This simulates an entire frame render over however many clock cycles it takes to render
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity FrameRenderTest is

end FrameRenderTest;

architecture TB of FrameRenderTest is
    
    signal clock: std_logic;
    signal reset: std_logic;

    signal address: std_logic_vector(13 downto 0);
    signal entry: FramebufferEntry;
    signal writeEn: std_logic;
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

    DRIVEN: FrameRenderer port map(
        clock => clock,
        reset => reset,
        readingFromMemory => '0',
        endFrameEn => '0',
        
        readData => (
            depth => "0111111111111111",
            color => "00000"
        ),

        writeAddress => address,
        writeData => entry,
        writeEn => writeEn
    );
    SCANLINE_REPORTER: process
    begin
        loop
            wait until rising_edge(clock);
            if writeEn = '1' and entry.color /= "00000" then
                ReportPixel(
                    (
                        address => address,
                        z => entry.depth,
                        color => entry.color
                    )
                );
            end if;
        end loop;
    end process;
end TB;