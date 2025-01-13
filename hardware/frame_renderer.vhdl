library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;
use work.basys3d_arithmetic.all;

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

    signal color: std_logic_vector(4 downto 0);

    signal plotTriangleEn: std_logic;
    signal plotterReadyMode: std_logic;

    signal plotterEmpty: std_logic;

    signal point1: Vector16;
    signal point2: Vector16;
    signal point3: Vector16;
    signal normal: Vector16;

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
begin

    bufferSelect <= bufferSelectInt;

    TRIANGLE_CONTROLLER: process(clock, reset)
        type controller_state_t is (
            StartingClear, 
            WaitingForClearToEnd, 

            -- Let's hard code all the triangles
            AddingTetrahedralTriangle1,
            AddingTetrahedralTriangle2,
            AddingTetrahedralTriangle3,
            AddingTetrahedralTriangle4,
            AddingTetrahedralTriangle5,
            AddingTetrahedralTriangle6,

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
            point1 <= (others => (others => '0'));
            point2 <= (others => (others => '0'));
            point3 <= (others => (others => '0'));
            normal <= (others => (others => '0'));

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
                        state := AddingTetrahedralTriangle1;
                    end if;
                when AddingTetrahedralTriangle1 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, 5792, 0);
                        point2 <= CreateVector16(-5792, -5792, 0);
                        point3 <= CreateVector16(0, -5792, -5792);
                        normal <= CreateVector16(-170, 85, -170);
                        plotTriangleEn <= '1';
                        report "Finished adding first triangle!";
                        state := AddingTetrahedralTriangle2;
                        stallCycles := 3;
                    end if;
                when AddingTetrahedralTriangle2 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, 5792, 0);
                        point2 <= CreateVector16(0, -5792, -5792);
                        point3 <= CreateVector16(5792, -5792, 0);
                        normal <= CreateVector16(170, 85, -170);
                        plotTriangleEn <= '1';
                        report "Finished adding second triangle!";
                        state := AddingTetrahedralTriangle3;
                        stallCycles := 3;
                    end if;
                when AddingTetrahedralTriangle3 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, 5792, 0);
                        point2 <= CreateVector16(0, -5792, 5792);
                        point3 <= CreateVector16(-5792, -5792, 0);
                        normal <= CreateVector16(-170, 85, 170);
                        plotTriangleEn <= '1';
                        report "Finished adding third triangle!";
                        state := AddingTetrahedralTriangle4;
                        stallCycles := 3;
                    end if;
                when AddingTetrahedralTriangle4 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, 5792, 0);
                        point2 <= CreateVector16(5792, -5792, 0);
                        point3 <= CreateVector16(0, -5792, 5792);
                        normal <= CreateVector16(170, 85, 170);
                        plotTriangleEn <= '1';
                        report "Finished adding fourth triangle!";
                        state := AddingTetrahedralTriangle5;
                        stallCycles := 3;
                    end if;
                when AddingTetrahedralTriangle5 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, -5792, -5792);
                        point2 <= CreateVector16(-5792, -5792, 0);
                        point3 <= CreateVector16(5792, -5792, 0);
                        normal <= CreateVector16(0, -256, 0);
                        plotTriangleEn <= '1';
                        report "Finished adding fifth triangle!";
                        state := AddingTetrahedralTriangle6;
                        stallCycles := 3;
                    end if;
                when AddingTetrahedralTriangle6 =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif plotterReadyMode then
                        point1 <= CreateVector16(0, -5792, 5792);
                        point2 <= CreateVector16(5792, -5792, 0);
                        point3 <= CreateVector16(-5792, -5792, 0);
                        normal <= CreateVector16(0, -256, 0);
                        plotTriangleEn <= '1';
                        report "Finished adding sixth triangle!";
                        state := WaitingForRender;
                        stallCycles := 3;
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


    -- Notes for the first full triangle render stuff
    -- Transformation matrix is going to be the identity matrix
    -- Light direction will be coming from a bit to the right of the viewer and a bit up from the viewer
    -- So positive z, negative x, negative y
    -- (0.2588190451, 0.2588190451, 1)
    --
    -- Becomes
    -- (0.243049, 0.243049, 0.939071)
    --
    -- Which is ~ [63, 63, 240] (as normalized as possible)

    TRIANGLE_RENDERER: TriangleRenderer
    port map (
        clock            => clock,
        reset            => reset,
        readyForTriangle => plotterReadyMode,
        renderTriangleEn => plotTriangleEn,
        point1           => point1,
        point2           => point2,
        point3           => point3,
        normal           => normal,
        lightDirection   => (
        x => to_signed(63,16),
        y => to_signed(63,16),
        z => to_signed(240,16)
        ),
        -- Identity matrix
        worldToViewspace => (
        Row1 => (x => to_signed(256,16), y => to_signed(0,16), z => to_signed(0,16)),
        Row2 => (x => to_signed(0,16), y => to_signed(256,16), z => to_signed(0,16)),
        Row3 => (x => to_signed(0,16), y => to_signed(0,16), z => to_signed(256,16))
        ),
        pipelineEmpty    => plotterEmpty,
        writeAddress => plotterWriteAddress,
        writeData => plotterWriteData,
        readAddress => readAddress,
        readData => readData,
        writeEn => plotterWriteEn
    );

    -- Triangle plotter
    -- TRIANGLE_PLOTTER: TrianglePlotter port map (
    --     clock => clock,
    --     reset => reset,
    --     x1 => x1,
    --     y1 => y1,
    --     z1 => z1,
    --     x2 => x2,
    --     y2 => y2,
    --     z2 => z2,
    --     x3 => x3,
    --     y3 => y3,
    --     z3 => z3,

    --     color => color,

    --     plotTriangleEn => plotTriangleEn,

    --     pipelineEmpty => plotterEmpty,

    --     readyMode => plotterReadyMode,

    --     writeAddress => plotterWriteAddress,
    --     writeData => plotterWriteData,
    --     readAddress => readAddress,
    --     readData => readData,
    --     writeEn => plotterWriteEn
    -- );

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