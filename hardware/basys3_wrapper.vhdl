library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;

entity Basys3Wrapper is
    port (
        clk: in STD_LOGIC;
        btnC: in STD_LOGIC; -- reset
        btnU: in STD_LOGIC;
        btnD: in STD_LOGIC;
        btnL: in STD_LOGIC;
        btnR: in STD_LOGIC;
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
end Basys3Wrapper;

architecture Wrapper of Basys3Wrapper is
    
    signal vgaAddress: std_logic_vector(13 downto 0);
    signal vgaData: FramebufferEntry;
    
    signal readAddress: std_logic_vector(13 downto 0);
    signal readData: FramebufferEntry;
    signal writeAddress: std_logic_vector(13 downto 0);
    signal writeData: FramebufferEntry;
    signal writeEn: std_logic;

    signal scale: VgaScale;
    
    signal readingFromMemory: std_logic;
    signal endFrameEn: std_logic;
    
    signal bufferSelect: std_logic;

    signal digit0i: integer range 0 to 9;
    signal digit0: std_logic_vector(3 downto 0);
    signal digit1i: integer range 0 to 9;
    signal digit1: std_logic_vector(3 downto 0);
    signal blank1: std_logic;
    signal digit2i: integer range 0 to 9;
    signal digit2: std_logic_vector(3 downto 0);
    signal blank2: std_logic;
    signal digit3i: integer range 0 to 9;
    signal digit3: std_logic_vector(3 downto 0);
    signal blank3: std_logic;
begin

    SCALE_SELECT: process(sw)
    begin
        if sw(1) then
            scale <= TripleRes;
        elsif sw(0) then
            scale <= DoubleRes;
        else
            scale <= SingleRes;
        end if;
    end process;

    DRIVER: VgaDriver port map(
        clock => clk,
        reset => btnC,

        addr => vgaAddress,
        fbe => vgaData,
        scale => scale,
        
        readingFromMemory => readingFromMemory,
        endFrameEn => endFrameEn,

        red => vgaRed,
        green => vgaGreen,
        blue => vgaBlue,
        hSync => Hsync,
        vSync => Vsync
    );
    
    led(15) <= readingFromMemory;
    
    led(14) <= bufferSelect;
    
    led(13 downto 0) <= vgaAddress;
    
    DUAL_BUFFER: DualBuffer port map (
        clock => clk,
        
        currentWriteBuffer => bufferSelect,
        vgaAddress => vgaAddress,
        outVga => vgaData,
    
        readAddress => readAddress,
        writeAddress => writeAddress,
        readData => readData,
        writeData => writeData,
        writeEn => writeEn
    );

    RENDERER: FrameRenderer port map(
        clock => clk,
        reset => btnC,

        readingFromMemory => readingFromMemory,
        endFrameEn => endFrameEn,

        bufferSelect => bufferSelect,
    
        readAddress => readAddress,
        writeAddress => writeAddress,
        readData => readData,
        writeData => writeData,
        writeEn => writeEn,

        fpsOne => digit0i,
        fpsTwo => digit1i,
        fpsThree => digit2i,
        fpsFour => digit3i,
        left => btnL,
        right => btnR,
        up => btnU,
        down => btnD
    );

    digit0 <= std_logic_vector(to_unsigned(digit0i,4));
    digit1 <= std_logic_vector(to_unsigned(digit1i,4));
    digit2 <= std_logic_vector(to_unsigned(digit2i,4));
    digit3 <= std_logic_vector(to_unsigned(digit3i,4));

    BLANK_STUFF: process(digit1i,digit2i,digit3i)
    begin
        if digit3i = 0 then
            blank3 <= '1';
        else
            blank3 <= '0';
        end if;
        
        if digit3i = 0 and digit2i = 0 then
            blank2 <= '1';
        else
            blank2 <= '0';
        end if;
        
        if digit3i = 0 and digit2i = 0 and digit1i = 0 then
            blank1 <= '1';
        else
            blank1 <= '0';
        end if;
    end process;

    SEVEN_SEG: SevenSegmentDriver port map (
        reset => btnC,
        clock => clk,

        digit3 => digit3,
        digit2 => digit2,
        digit1 => digit1,
        digit0 => digit0,

        blank3 => blank3,
        blank2 => blank2,
        blank1 => blank1,
        blank0 => '0',
        sevenSegs => seg,
        anodes => an
    );
end Wrapper;