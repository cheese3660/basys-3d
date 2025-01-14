library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;
use work.basys3d_arithmetic.all;
use work.basys3d_geometry.all;
use work.basys3d_communication.all;

entity FrameRenderer is
    generic (
        MAX_TRIANGLE_COUNT: integer range 0 to 65535
    );
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

        -- Transformation control signals
        left: in std_logic;
        right: in std_logic;
        up: in std_logic;
        down: in std_logic;

        -- Geobuffer signals
        triangleCount: in integer range 0 to MAX_TRIANGLE_COUNT;
        geoData: in GeoTriangle;
        geoAddress: out integer range 0 to MAX_TRIANGLE_COUNT-1;


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

    -- Rotation signals
    signal thetaX: signed(15 downto 0) := (others => '0');
    signal thetaY: signed(15 downto 0) := (others => '0');
    signal transformationMatrix: Matrix16;
    signal beginGenerate: std_logic;
    signal generationDoneMode: std_logic;
begin

    bufferSelect <= bufferSelectInt;

    TRIANGLE_CONTROLLER: process(clock, reset)
        type controller_state_t is (
            StartingClearAndTransformationGen,
            WaitingForClearAndTransformationToEnd,
            ReadingTriangle,
            WaitingForRead,
            AddingToPipeline,
            WaitingForRender, 
            FlippingBuffers, 
            Stall);

        variable state: controller_state_t := StartingClearAndTransformationGen;

        variable stallCycles: integer range 0 to 3 := 0;

        variable triangleIndex: integer range 0 to MAX_TRIANGLE_COUNT-1 := 0;

    begin
        if reset then
            state := StartingClearAndTransformationGen;
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
            beginGenerate <= '0';
            case state is
                when StartingClearAndTransformationGen =>
                    startBufferClearEn <= '1';
                    beginGenerate <= '1';
                    state := WaitingForClearAndTransformationToEnd;
                    stallCycles := 3;
                when WaitingForClearAndTransformationToEnd =>
                    if stallCycles > 0 then
                        stallCycles := stallCycles - 1;
                    elsif generationDoneMode and not clearingBufferMode and not startBufferClearEn then
                        if triangleCount /= 0 then
                            triangleIndex := 0;
                            state := ReadingTriangle;
                        else
                            state := WaitingForRender;
                        end if;
                    end if;
                when ReadingTriangle =>
                    geoAddress <= triangleIndex;
                    state := WaitingForRead;
                when WaitingForRead =>
                    state := AddingToPipeline;
                when AddingToPipeline =>
                    if plotterReadyMode then
                        point1 <= geoData.A;
                        point2 <= geoData.B;
                        point3 <= geoData.C;
                        normal <= geoData.N;
                        plotTriangleEn <= '1';
                        if triangleIndex /= triangleCount-1 then
                            triangleIndex := triangleIndex + 1;
                            state := ReadingTriangle;
                        else
                            stallCycles := 3;
                            state := WaitingForRender;
                        end if;
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
                        state := StartingClearAndTransformationGen;
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
        x => to_signed(-63,16),
        y => to_signed(-63,16),
        z => to_signed(240,16)
        ),
        -- Generated matrix
        worldToViewspace => transformationMatrix,
        pipelineEmpty    => plotterEmpty,
        writeAddress => plotterWriteAddress,
        writeData => plotterWriteData,
        readAddress => readAddress,
        readData => readData,
        writeEn => plotterWriteEn
    );

    -- The matrix calculator
    MATRIX_GENERATOR: MatrixGenerator
    port map (
      clock                => clock,
      reset                => reset,
      thetaA               => thetaX,
      thetaB               => thetaY,
      beginGenerate        => beginGenerate,
      transformationMatrix => transformationMatrix,
      generationDoneMode   => generationDoneMode
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

    CONSTANT_ROTATOR: process(clock, reset) is
        constant ROTATION_AMOUNT: signed(15 downto 0) := to_signed(1 * 256, 16);
    begin
        if reset then
            thetaX <= (others => '0');
            thetaY <= (others => '0');
        elsif rising_edge(clock) then
            if endFrameEn then
                if left then
                    thetaY <= thetaY + ROTATION_AMOUNT;
                elsif right then
                    thetaY <= thetaY - ROTATION_AMOUNT;
                end if;
                if up then
                    thetaX <= thetaX + ROTATION_AMOUNT;
                elsif down then
                    thetaX <= thetaX - ROTATION_AMOUNT;
                end if;
            end if;
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