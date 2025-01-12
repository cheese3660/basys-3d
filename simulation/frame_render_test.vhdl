-- This simulates an entire frame render over however many clock cycles it takes to render
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;

entity FrameRenderTest is

end FrameRenderTest;

architecture TB of FrameRenderTest is
    
    signal clock: std_logic;
    signal reset: std_logic;

    signal address: std_logic_vector(13 downto 0);
    signal readAddress: std_logic_vector(13 downto 0);
    signal readData: FramebufferEntry;
    signal entry: FramebufferEntry;
    signal writeEn: std_logic;

    signal bufferSelect: std_logic;
    signal vgaAddress: std_logic_vector(13 downto 0);
    signal vgaData: FramebufferEntry;
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

    
    
    DUAL_BUFFER: DualBuffer port map (
        clock => clock,
        
        currentWriteBuffer => bufferSelect,
        vgaAddress => vgaAddress,
        outVga => vgaData,
    
        readAddress => readAddress,
        writeAddress => address,
        readData => readData,
        writeData => entry,
        writeEn => writeEn
    );


    -- Only clock it for the first frame
    DRIVEN: FrameRenderer port map(
        clock => clock and not bufferSelect,
        reset => reset,
        readingFromMemory => '0',
        endFrameEn => '0',
        readAddress => readAddress,
        readData => readData,
        writeAddress => address,
        writeData => entry,
        writeEn => writeEn,
        bufferSelect => bufferSelect
    );
    SCANLINE_REPORTER: process
    begin
        wait for 1000 ns;
        wait until bufferSelect = '1';
        for i in 0 to 16383 loop
            vgaAddress <= std_logic_vector(to_unsigned(i,14));
            wait until rising_edge(clock);
            wait until rising_edge(clock);
            if vgaData.color /= "00000" then
                ReportPixel(
                    (
                        address => vgaAddress,
                        z => vgaData.depth,
                        color => vgaData.color
                    )
                );
            end if;
            wait until rising_edge(clock);
        end loop;
        wait;
    end process;
end TB;