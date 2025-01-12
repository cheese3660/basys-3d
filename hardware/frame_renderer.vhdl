library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;

entity FrameRenderer is
    port (
        clock: in std_logic;
        reset: in std_logic;

        -- VGA Control Signals
        readingFromMemory: in std_logic;
        endFrameEn: in std_logic;

        -- Framebuffer control signals
        bufferSelect: out std_logic;

        readAddress: out std_logic_vector(13 downto 0);
        readData: in FramebufferEntry;

        writeAddress: out std_logic_vector(13 downto 0);
        writeEn: out std_logic;
        writeData: out FramebufferEntry;

        -- FPS Display
        fpsOne: out integer range 0 to 9;
        fpsTwo: out integer range 0 to 9;
        fpsThree: out integer range 0 to 9;
        fpsFour: out integer range 0 to 9
    );
end FrameRenderer;

architecture Procedural of FrameRenderer is
    -- Scanline drawing signals

    signal x1: signed(15 downto 0);
    signal y1: signed(7 downto 0);
    signal z1: signed(15 downto 0);

    signal x2: signed(15 downto 0);
    signal y2: signed(7 downto 0);
    signal z2: signed(15 downto 0);

    signal x3: signed(15 downto 0);
    signal y3: signed(7 downto 0);
    signal z3: signed(15 downto 0);

    signal color: std_logic_vector(4 downto 0);

    signal plotTriangleEn: std_logic;
    signal plotterReadyMode: std_logic;

    signal plotterEmpty: std_logic;

    -- Pixel drawing signals
    signal plotterWriteAddress: std_logic_vector(13 downto 0);
    signal plotterWriteData: FramebufferEntry;
    signal plotterWriteEn: std_logic;

    -- Support signals
    signal countFpsEn: std_logic;
    signal clearingBufferMode: std_logic := '0';
    signal startBufferClearEn: std_logic;

    signal clearAddress: unsigned(13 downto 0) := (others => '0');


    signal bufferSelectInt: std_logic;

    signal scanlineWriteSelect: std_logic := '0';
begin

    bufferSelect <= bufferSelectInt;

    TRIANGLE_CONTROLLER: process(clock, reset)
        type controller_state_t is (
            StartingClear, 
            WaitingForClearToEnd, 

            -- Let's hard code all the triangles
            AddingFaceTriangle1,
            AddingFaceTriangle2,
            AddingFaceTriangle3,
            AddingFaceTriangle4,
            AddingFaceTriangle5,
            AddingFaceTriangle6,
            AddingFaceTriangle7,
            AddingFaceTriangle8,

            AddingEyeTriangle1,
            AddingEyeTriangle2,
            AddingEyeTriangle3,
            AddingEyeTriangle4,

            AddingNoseTriangle,
            AddingMouthTriangle,

            WaitingForRender, 
            FlippingBuffers, 
            Stall);

        variable state: controller_state_t := StartingClear;

        variable stallCycles: integer range 0 to 3 := 0;
    begin
        if reset then
            state := StartingClear;
            bufferSelectInt <= '0';
            stallCycles := 0;
        elsif rising_edge(clock) then
            startBufferClearEn <= '0';

            countFpsEn <= '0';
            x1 <= (others => '0');
            y1 <= (others => '0');
            z1 <= (others => '0');

            x2 <= (others => '0');
            y2 <= (others => '0');
            z2 <= (others => '0');

            x3 <= (others => '0');
            y3 <= (others => '0');
            z3 <= (others => '0');

            color <= "00000";

            plotTriangleEn <= '0';
            case state is
                when StartingClear =>
                    startBufferClearEn <= '1';
                    state := WaitingForClearToEnd;
                    stallCycles := 3;
                when WaitingForClearToEnd =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif not clearingBufferMode and not startBufferClearEn then
                        state := AddingFaceTriangle1;
                    end if;
                when AddingFaceTriangle1 =>
                    -- Start with the flat triangles to be able to bang them through the pipeline
                    x1 <= to_signed(16*256, 16);
                    y1 <= to_signed(64, 8);
                    z1 <= to_signed(1 * 256, 16);

                    x2 <= to_signed(30*256,16);
                    y2 <= to_signed(30,8);
                    z2 <= to_signed(1 * 256, 16);

                    x3 <= to_signed(64*256,16);
                    y3 <= to_signed(64, 8);
                    z3 <= to_signed(1 * 256, 16);

                    color <= "01111";

                    plotTriangleEn <= '1';
                    stallCycles := 3;
                    state := AddingFaceTriangle2;
                when AddingFaceTriangle2 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(94*256,16);
                        y2 <= to_signed(30,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(112*256,16);
                        y3 <= to_signed(64, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingFaceTriangle3;
                    end if;
                when AddingFaceTriangle3 =>
                
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(16*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(30*256,16);
                        y2 <= to_signed(94,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(64*256,16);
                        y3 <= to_signed(64, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingFaceTriangle4;
                    end if;
                when AddingFaceTriangle4 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(112*256,16);
                        y2 <= to_signed(64,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(94*256,16);
                        y3 <= to_signed(94, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingFaceTriangle5;
                    end if;
                when AddingFaceTriangle5 =>
                    -- Now lets stop doing the flat triangles
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(30*256,16);
                        y2 <= to_signed(30,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(64*256,16);
                        y3 <= to_signed(16, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        stallCycles := 3;
                        plotTriangleEn <= '1';
                        state := AddingFaceTriangle6;
                    end if;
                when AddingFaceTriangle6 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);
    
                        x2 <= to_signed(64*256,16);
                        y2 <= to_signed(16,8);
                        z2 <= to_signed(1 * 256, 16);
    
                        x3 <= to_signed(94*256,16);
                        y3 <= to_signed(30, 8);
                        z3 <= to_signed(1 * 256, 16);
    
                        color <= "01111";
    
                        stallCycles := 3;
                        plotTriangleEn <= '1';
                        state := AddingFaceTriangle7;
                    end if;
                when AddingFaceTriangle7 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(94*256,16);
                        y2 <= to_signed(94,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(64*256,16);
                        y3 <= to_signed(112, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        stallCycles := 3;
                        plotTriangleEn <= '1';
                        state := AddingFaceTriangle8;
                    end if;

                when AddingFaceTriangle8 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(1 * 256, 16);

                        x2 <= to_signed(64*256,16);
                        y2 <= to_signed(112,8);
                        z2 <= to_signed(1 * 256, 16);

                        x3 <= to_signed(30*256,16);
                        y3 <= to_signed(94, 8);
                        z3 <= to_signed(1 * 256, 16);

                        color <= "01111";

                        stallCycles := 3;
                        plotTriangleEn <= '1';
                        state := AddingEyeTriangle1;
                    end if;
                
                when AddingEyeTriangle1 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(40*256, 16);
                        y1 <= to_signed(48, 8);
                        z1 <= to_signed(0 * 256, 16);
    
                        x2 <= to_signed(48*256,16);
                        y2 <= to_signed(40,8);
                        z2 <= to_signed(0 * 256, 16);
    
                        x3 <= to_signed(56*256,16);
                        y3 <= to_signed(48, 8);
                        z3 <= to_signed(0 * 256, 16);
    
                        color <= "00111";
    
                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingEyeTriangle2;
                    end if;
                when AddingEyeTriangle2 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(40*256, 16);
                        y1 <= to_signed(48, 8);
                        z1 <= to_signed(0 * 256, 16);

                        x2 <= to_signed(48*256,16);
                        y2 <= to_signed(56,8);
                        z2 <= to_signed(0 * 256, 16);

                        x3 <= to_signed(56*256,16);
                        y3 <= to_signed(48, 8);
                        z3 <= to_signed(0 * 256, 16);

                        color <= "00111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingEyeTriangle3;
                    end if;
                when AddingEyeTriangle3 =>
                
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(72*256, 16);
                        y1 <= to_signed(48, 8);
                        z1 <= to_signed(0 * 256, 16);

                        x2 <= to_signed(80*256,16);
                        y2 <= to_signed(40,8);
                        z2 <= to_signed(0 * 256, 16);

                        x3 <= to_signed(88*256,16);
                        y3 <= to_signed(48, 8);
                        z3 <= to_signed(0 * 256, 16);

                        color <= "00111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingEyeTriangle4;
                    end if;
                when AddingEyeTriangle4 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(72*256, 16);
                        y1 <= to_signed(48, 8);
                        z1 <= to_signed(0 * 256, 16);

                        x2 <= to_signed(80*256,16);
                        y2 <= to_signed(56,8);
                        z2 <= to_signed(0 * 256, 16);

                        x3 <= to_signed(88*256,16);
                        y3 <= to_signed(48, 8);
                        z3 <= to_signed(0 * 256, 16);

                        color <= "00111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingNoseTriangle;
                    end if;
                when AddingNoseTriangle =>
                
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(64*256, 16);
                        y1 <= to_signed(64, 8);
                        z1 <= to_signed(0 * 256, 16);

                        x2 <= to_signed(60*256,16);
                        y2 <= to_signed(68,8);
                        z2 <= to_signed(0 * 256, 16);

                        x3 <= to_signed(68*256,16);
                        y3 <= to_signed(68, 8);
                        z3 <= to_signed(0 * 256, 16);

                        color <= "10011";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := AddingMouthTriangle;
                    end if;
                when AddingMouthTriangle =>                
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        x1 <= to_signed(44*256, 16);
                        y1 <= to_signed(80, 8);
                        z1 <= to_signed(0 * 256, 16);

                        x2 <= to_signed(64*256,16);
                        y2 <= to_signed(88,8);
                        z2 <= to_signed(0 * 256, 16);

                        x3 <= to_signed(84*256,16);
                        y3 <= to_signed(80, 8);
                        z3 <= to_signed(0 * 256, 16);

                        color <= "11111";

                        plotTriangleEn <= '1';
                        stallCycles := 3;
                        state := WaitingForRender;
                    end if;
                when WaitingForRender =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterEmpty and not plotTriangleEn then
                        countFpsEn <= '1';
                        state := FlippingBuffers;
                    end if;
                when FlippingBuffers =>
                    if not readingFromMemory then
                        bufferSelectInt <= not bufferSelectInt;
                        state := StartingClear;
                    end if;
                when Stall =>
                    state := Stall;
            end case;
        end if;
    end process;

    -- Triangle plotter
    TRIANGLE_PLOTTER: TrianglePlotter port map (
        clock => clock,
        reset => reset,
        x1 => x1,
        y1 => y1,
        z1 => z1,
        x2 => x2,
        y2 => y2,
        z2 => z2,
        x3 => x3,
        y3 => y3,
        z3 => z3,

        color => color,

        plotTriangleEn => plotTriangleEn,

        pipelineEmpty => plotterEmpty,

        readyMode => plotterReadyMode,

        writeAddress => plotterWriteAddress,
        writeData => plotterWriteData,
        readAddress => readAddress,
        readData => readData,
        writeEn => plotterWriteEn
    );

    -- Support logic for the renderer
    FRAME_CLEARER: process(clock)
    begin
        if rising_edge(clock) then
            if clearingBufferMode then
                if clearAddress = "11111111111111" then
                    clearingBufferMode <= '0';
                else
                    clearAddress <= clearAddress + 1;
                end if;
            elsif startBufferClearEn then
                clearAddress <= (others => '0');
                clearingBufferMode <= '1';
            end if;
        end if;
    end process;

    WRITE_MUX: process(all)
    begin
        if clearingBufferMode or startBufferClearEn then
            writeEn <= '1';
            writeData <= (
                depth => "0111111111111111",
                color => "00000"
            );
            writeAddress <= std_logic_vector(clearAddress);
        else
            writeEn <= plotterWriteEn;
            writeData <= plotterWriteData;
            writeAddress <= plotterWriteAddress;
        end if;
    end process;

    FPS_COUNTER: process(clock, reset) is
        variable backFpsOne: integer range 0 to 9 := 0;
        variable backFpsTwo: integer range 0 to 9 := 0;
        variable backFpsThree: integer range 0 to 9 := 0;
        variable backFpsFour: integer range 0 to 9 := 0;

        variable timer: integer range 0 to 59 := 0;
    begin
        if reset then
            backFpsOne := 0;
            backFpsTwo := 0;
            backFpsThree := 0;
            backFpsFour := 0;
            timer := 0;
        elsif rising_edge(clock) then
            if countFpsEn then
                if backFpsOne = 9 then
                    backFpsOne := 0;
                    if backFpsTwo = 9 then
                        backFpsTwo := 0;
                        if backFpsThree = 9 then
                            backFpsThree := 0;
                            if backFpsFour /= 9 then
                                backFpsFour := backFpsFour + 1;
                            end if;
                        else
                            backFpsThree := backFpsThree + 1;
                        end if;
                    else
                        backFpsTwo := backFpsTwo + 1;
                    end if;
                else
                    backFpsOne := backFpsOne + 1;
                end if;
            end if;
            if endFrameEn then
                if timer = 59 then
                    timer := 0;
                    fpsOne <= backFpsOne;
                    fpsTwo <= backFpsTwo;
                    fpsThree <= backFpsThree;
                    fpsFour <= backFpsFour;
                    backFpsOne := 0;
                    backFpsTwo := 0;
                    backFpsThree := 0;
                    backFpsFour := 0;
                else
                    timer := timer+1;
                end if;
            end if;
        end if;
    end process;
end architecture;