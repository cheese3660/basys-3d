library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Now let's add all the signals that the VGA driver needs to actually draw stuff
entity VgaDriver is
    Port(
        clock: in std_logic;
        reset: in std_logic;


        red: out std_logic_vector(3 downto 0);
        green: out std_logic_vector(3 downto 0);
        blue: out std_logic_vector(3 downto 0);

        hSync: out std_logic;
        vSync: out std_logic
    );
end VgaDriver;


architecture Procedural of VgaDriver is
    signal nextPixel: std_logic := '0';
begin
    PIXEL_CLOCK: process(clock, reset)
        variable current: integer range 0 to 3;
    begin
        if reset then
            current := 0;
        elsif rising_edge(clock) then
            if current = 3 then
                nextPixel <= '1';
                current := 0;
            else
                nextPixel <= '0';
                current := current + 1;
            end if;
        end if;
    end process;

    -- We can currently do this in a single state, updating values when needed
    DRIVER: process(clock, reset)
        variable scanline: integer range 0 to 524 := 0;
        variable pixel: integer range 0 to 799 := 0;

        constant hblank: integer := 640;
        constant hsync_begin: integer := hblank+16;
        constant hsync_end: integer := hsync_begin+96;

        constant vblank: integer := 480;
        constant vsync_begin: integer := vblank+10;
        constant vsync_end: integer := vsync_begin+2;

        variable blanking: boolean;
        variable h_syncing: boolean;
        variable v_syncing: boolean;

        variable scanline_bits: std_logic_vector(9 downto 0);
        variable pixel_bits: std_logic_vector(9 downto 0);
    begin
        if reset then
            scanline := 0;
            pixel := 0;
        elsif rising_edge(clock) then
            blanking := scanline >= vblank or pixel >= hblank;
            h_syncing := pixel >= hsync_begin and pixel < hsync_end;
            v_syncing := scanline >= vsync_begin and scanline < vsync_end;
            scanline_bits := std_logic_vector(to_unsigned(scanline,10));
            pixel_bits := std_logic_vector(to_unsigned(pixel,10));
            if nextPixel then
                -- First let's output the information for the current pixel
                if blanking then
                    red <= "0000";
                    green <= "0000";
                    blue <= "0000";
                    if h_syncing then
                        hSync <= '0';
                    else
                        hSync <= '1';
                    end if;

                    if v_syncing then
                        vSync <= '0';
                    else
                        vSync <= '1';
                    end if;
                else
                    hSync <= '1';
                    vSync <= '1';
                    red <= pixel_bits(3 downto 0);
                    green <= scanline_bits(3 downto 0);
                    blue <= scanline_bits(7 downto 4);
                end if;
                -- Then go to the next pixel
                if pixel = 799 then
                    pixel := 0;
                    if scanline = 524 then
                        scanline := 0;
                    else
                        scanline := scanline + 1;
                    end if;     
                else
                    pixel := pixel + 1;
                end if;
            end if;    
        end if;
    end process;
end Procedural;