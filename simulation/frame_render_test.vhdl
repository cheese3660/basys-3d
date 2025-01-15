-- This simulates an entire frame render over however many clock cycles it takes to render
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;
use work.basys3d_arithmetic.all;
use work.basys3d_geometry.all;

entity FrameRenderTest is

end FrameRenderTest;

architecture TB of FrameRenderTest is
    
    signal clock: std_logic;
    signal reset: std_logic;

    signal address: std_logic_vector(13 downto 0);
    signal readAddress: std_logic_vector(13 downto 0);
    signal readData: signed(15 downto 0);
    signal entry: FramebufferEntry;
    signal writeEn: std_logic;

    signal bufferSelect: std_logic;
    signal vgaAddress: std_logic_vector(13 downto 0);
    signal vgaData: Color;

    -- let's now implement the geobuffer
    
    constant MAX_TRIG_COUNT: integer := 6;
    type pyramidArray is array (0 to 5) of GeoTriangle;
    constant PYRAMID : pyramidArray := (
        (
            A => CreateVector16(0,5792,0),
            B => CreateVector16(-5792, -5792, 0),
            C => CreateVector16(0, -5792, -5792),
            N => CreateVector10(-170, 85, -170),
            COL => CreateColor(31,31,31)
        ),
        (
            A => CreateVector16(0,5792,0),
            B => CreateVector16(0, -5792, -5792),
            C => CreateVector16(5792, -5792, 0),
            N => CreateVector10(170, 85, -170),
            COL => CreateColor(31,31,31)
        ),
        (
            A => CreateVector16(0,5792,0),
            B => CreateVector16(0, -5792, 5792),
            C => CreateVector16(-5792, -5792, 0),
            N => CreateVector10(-170, 85, 170),
            COL => CreateColor(31,31,31)
        ),
        (
            A => CreateVector16(0,5792,0),
            B => CreateVector16(5792, -5792, 0),
            C => CreateVector16(0, -5792, 5792),
            N => CreateVector10(170, 85, 170),
            COL => CreateColor(31,31,31)
        ),
        (
            A => CreateVector16(0, -5792, -5792),
            B => CreateVector16(-5792, -5792, 0),
            C => CreateVector16(5792, -5792, 0),
            N => CreateVector10(0, -256, 0),
            COL => CreateColor(31,31,31)
        ),
        (
            A => CreateVector16(0, -5792, 5792),
            B => CreateVector16(5792, -5792, 0),
            C => CreateVector16(-5792, -5792, 0),
            N => CreateVector10(0, -256, 0),
            COL => CreateColor(31,31,31)
        )
    );

    signal geoData: GeoTriangle;
    signal geoAddress: integer range 0 to MAX_TRIG_COUNT-1;
    signal fpsOne: integer range 0 to 9;
    signal fpsTwo: integer range 0 to 9;
    signal fpsThree: integer range 0 to 9;
    signal fpsFour: integer range 0 to 9;

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

    GEO_EMU: process
    begin
        wait until rising_edge(clock);
        geoData <= PYRAMID(geoAddress);
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
    DRIVEN: FrameRenderer generic map (
        MAX_TRIANGLE_COUNT => MAX_TRIG_COUNT
    ) port map(
        clock => clock and not bufferSelect,
        reset => reset,
        readingFromMemory => '0',
        endFrameEn => '0',
        readAddress => readAddress,
        readData => readData,
        writeAddress => address,
        writeData => entry,
        writeEn => writeEn,
        bufferSelect => bufferSelect,
        left => '0',
        right => '0',
        up => '0',
        down => '0',
        triangleCount=> 6,
        geoData=> geoData,
        geoAddress=> geoAddress,
        fpsOne=> fpsOne,
        fpsTwo=> fpsTwo,
        fpsThree=> fpsThree,
        fpsFour=> fpsFour
    );
    SCANLINE_REPORTER: process
    begin
        wait for 1000 ns;
        wait until bufferSelect = '1';
        for i in 0 to 16383 loop
            vgaAddress <= std_logic_vector(to_unsigned(i,14));
            wait until rising_edge(clock);
            wait until rising_edge(clock);
            if vgaData /= ("00000","00000","00000") then
                ReportPixel(
                    vgaAddress,
                    vgaData
                );
            end if;
            wait until rising_edge(clock);
        end loop;
        wait;
    end process;
end TB;