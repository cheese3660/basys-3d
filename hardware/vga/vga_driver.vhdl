library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;


-- Now let's add all the signals that the VGA driver needs to actually draw stuff
entity VgaDriver is
    Port(
        clock: in std_logic;
        reset: in std_logic;

        -- This is the address that the VGA circuitry is reading from
        addr: out std_logic_vector(13 downto 0);
        fbe: in FramebufferEntry;

        -- This is the current scale of the VGA display
        scale: in VgaScale;

        -- Is the VGA display currently reading from memory (don't switch framebuffers while this is happening)
        readingFromMemory: out std_logic;

        -- Sent at the end of a frame to denote that a frame end has happened (will be used to count FPS)
        endFrameEn: out std_logic;

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
        
        variable framebufferX: integer range 0 to 127 := 0;
        variable framebufferY: integer range 0 to 127 := 0;

        variable fractionalFramebufferX: integer range 0 to 2 := 0;
        variable fractionalFramebufferY: integer range 0 to 2 := 0;

        constant singleScaleHorizontalStart: integer := (640 - 128) / 2;

        constant singleScaleHorizontalEnd: integer := singleScaleHorizontalStart+128;

        constant doubleScaleHorizontalStart: integer := (640 - 256) / 2;

        constant doubleScaleHorizontalEnd: integer := doubleScaleHorizontalStart+256;

        constant tripleScaleHorizontalStart: integer := (640 - 384) / 2;

        constant tripleScaleHorizontalEnd: integer := tripleScaleHorizontalStart+384;

        constant singleScaleVerticalStart: integer := (480 - 128) / 2;

        constant singleScaleVerticalEnd: integer := singleScaleVerticalStart+128;

        constant doubleScaleVerticalStart: integer := (480 - 256) / 2;

        constant doubleScaleVerticalEnd: integer := doubleScaleVerticalStart+256;

        constant tripleScaleVerticalStart: integer := (480 - 384) / 2;

        constant tripleScaleVerticalEnd: integer := tripleScaleVerticalStart+384;

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

        variable brighter_color: std_logic_vector(3 downto 0);

        variable drawFromMemory: boolean;
        variable inBorder: boolean;
        variable incrementStep: boolean;
    begin
        if reset then
            scanline := 0;
            pixel := 0;
            readingFromMemory <= '0';
            incrementStep := false;
            
        elsif rising_edge(clock) then
            endFrameEn <= '0';
            blanking := scanline >= vblank or pixel >= hblank;
            h_syncing := pixel >= hsync_begin and pixel < hsync_end;
            v_syncing := scanline >= vsync_begin and scanline < vsync_end;
            scanline_bits := std_logic_vector(to_unsigned(scanline,10));
            pixel_bits := std_logic_vector(to_unsigned(pixel,10));
            brighter_color := std_logic_vector(unsigned(fbe.color(4 downto 1)) + 1);

            case scale is
                when SingleRes =>
                    drawFromMemory := scanline >= singleScaleVerticalStart and pixel >= singleScaleHorizontalStart and scanline < singleScaleVerticalEnd and pixel <= singleScaleHorizontalEnd;
                    inBorder := scanline >= singleScaleVerticalStart-4 and pixel >= singleScaleHorizontalStart-4 and scanline < singleScaleVerticalEnd+4 and pixel <= singleScaleHorizontalEnd+4;
                when DoubleRes =>
                    drawFromMemory := scanline >= doubleScaleVerticalStart and pixel >= doubleScaleHorizontalStart and scanline < doubleScaleVerticalEnd and pixel <= doubleScaleHorizontalEnd;
                    inBorder := scanline >= doubleScaleVerticalStart-4 and pixel >= doubleScaleHorizontalStart-4 and scanline < doubleScaleVerticalEnd+4 and pixel <= doubleScaleHorizontalEnd+4;
                when TripleRes =>
                    drawFromMemory := scanline >= tripleScaleVerticalStart and pixel >= tripleScaleHorizontalStart and scanline < tripleScaleVerticalEnd and pixel <= tripleScaleHorizontalEnd;
                    inBorder := scanline >= tripleScaleVerticalStart-4 and pixel >= tripleScaleHorizontalStart-4 and scanline < tripleScaleVerticalEnd+4 and pixel <= tripleScaleHorizontalEnd+4;
            end case;
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

                    if drawFromMemory then
                        if (fbe.color(0) and (pixel_bits(0) xor scanline_bits(0))) = '1' and fbe.color /= "11111" then
                            red <= brighter_color;
                            green <= brighter_color;
                            blue <= brighter_color;
                        else
                            red <= fbe.color(4 downto 1);
                            green <= fbe.color(4 downto 1);
                            blue <= fbe.color(4 downto 1);
                        end if;
                    else
                        red <= "0000";
                        if inBorder then
                            green <= "0100";
                        else
                            green <= "0000";
                        end if;
                        blue <= "0000";
                    end if;
                end if;
                -- Go to the next pixel on the next clock cycle
                incrementStep := true;
            elsif incrementStep then
                if pixel = 799 then
                    pixel := 0;
                    if scanline = 524 then
                        endFrameEn <= '1';
                        scanline := 0;
                        readingFromMemory <= '0';
                    else
                        scanline := scanline + 1;
                        case scale is
                            when SingleRes =>
                                if scanline = singleScaleVerticalStart then
                                    framebufferY := 0;
                                    fractionalFramebufferY := 0;
                                    readingFromMemory <= '1';
                                elsif scanline = singleScaleVerticalEnd then
                                    readingFromMemory <= '0';
                                else
                                    framebufferY := framebufferY + 1;
                                end if;
                            when DoubleRes =>
                                if scanline = doubleScaleVerticalStart then
                                    framebufferY := 0;
                                    fractionalFramebufferY := 0;
                                    readingFromMemory <= '1';
                                elsif scanline = doubleScaleVerticalEnd then
                                    readingFromMemory <= '0';
                                elsif fractionalFramebufferY = 1 then
                                    fractionalFramebufferY := 0;
                                    framebufferY := framebufferY + 1;
                                else
                                    fractionalFramebufferY := fractionalFramebufferY + 1;
                                end if;
                            when TripleRes =>
                                if scanline = tripleScaleVerticalStart then
                                    framebufferY := 0;
                                    fractionalFramebufferY := 0;
                                    readingFromMemory <= '1';
                                elsif scanline = tripleScaleVerticalEnd then
                                    readingFromMemory <= '0';
                                elsif fractionalFramebufferY = 2 then
                                    fractionalFramebufferY := 0;
                                    framebufferY := framebufferY + 1;
                                else
                                    fractionalFramebufferY := fractionalFramebufferY + 1;
                                end if;
                        end case;
                    end if;
                else
                    pixel := pixel + 1;
                    case scale is
                        when SingleRes =>
                            if pixel = singleScaleHorizontalStart then
                                fractionalFramebufferX := 0;
                                framebufferX := 0;
                            else
                                framebufferX := framebufferX + 1;
                            end if;
                        when DoubleRes =>
                            if pixel = doubleScaleHorizontalStart then
                                fractionalFramebufferX := 0;
                                framebufferX := 0;
                            elsif fractionalFramebufferX = 1 then
                                framebufferX := framebufferX + 1;
                                fractionalFramebufferX := 0;
                            else
                                fractionalFramebufferX := fractionalFramebufferX + 1;
                            end if;
                        when TripleRes =>
                            if pixel = tripleScaleHorizontalStart then
                                fractionalFramebufferX := 0;
                                framebufferX := 0;
                            elsif fractionalFramebufferX = 2 then
                                framebufferX := framebufferX + 1;
                                fractionalFramebufferX := 0;
                            else
                                fractionalFramebufferX := fractionalFramebufferX + 1;
                            end if;
                    end case;
                end if;
                addr(13 downto 7) <= std_logic_vector(to_unsigned(framebufferY,7));
                addr(6 downto 0) <= std_logic_vector(to_unsigned(framebufferX,7));
                incrementStep := false;
            end if;
        end if;
    end process;
end Procedural;