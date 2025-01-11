library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

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
    signal s1y: unsigned(6 downto 0);
    signal s2y: unsigned(6 downto 0);
    signal s1x0: signed(7 downto 0);
    signal s1x1: signed(7 downto 0);
    signal s2x0: signed(7 downto 0);
    signal s2x1: signed(7 downto 0);
    signal s1color: std_logic_vector(4 downto 0);
    signal s2color: std_logic_vector(4 downto 0);
    signal s1drawLineEn: std_logic;
    signal s2drawLineEn: std_logic;

    signal s1Empty: std_logic;
    signal s2Empty: std_logic;

    -- Pixel drawing signals
    signal address1: std_logic_vector(13 downto 0);
    signal entry1: FramebufferEntry;
    signal plot1: std_logic;
    signal address2: std_logic_vector(13 downto 0);
    signal entry2: FramebufferEntry;
    signal plot2: std_logic;
    
    -- Support signals
    signal countFpsEn: std_logic;
    signal clearingBufferMode: std_logic;
    signal startBufferClearEn: std_logic;

    signal clearAddress: unsigned(13 downto 0);
    signal wantToWrite: std_logic;


    signal bufferSelectInt: std_logic;

    signal scanlineWriteSelect: std_logic := '0';
begin

    bufferSelect <= bufferSelectInt;
    -- Scanline controller

    SCANLINE_CONTROLLER: process(clock, reset)
        type controller_state_t is (StartingClear, WaitingForClearToEnd, AddingScanlines0, AddingScanlines1, WaitingForRender, FlippingBuffers);

        variable state: controller_state_t := StartingClear;
    begin
        if reset then
            state := StartingClear;
            bufferSelectInt <= '0';
        elsif rising_edge(clock) then
            startBufferClearEn <= '0';
            s1y <= (others => '0');
            s2y <= (others => '0');
            s1x0 <= (others => '0');
            s2x0 <= (others => '0');
            s1Color <= (others => '0');
            s2Color <= (others => '0');
            s1drawLineEn <= '0';
            s2drawLineEn <= '0';
            countFpsEn <= '0';
            case state is
                when StartingClear =>
                    startBufferClearEn <= '1';
                    state := WaitingForClearToEnd;
                when WaitingForClearToEnd =>
                    if not clearingBufferMode and not startBufferClearEn then
                        state := AddingScanlines0;
                    end if;
                when AddingScanlines0 =>
                    -- We need to set up all the values
                    s1y <= to_unsigned(20,7);
                    s2y <= to_unsigned(40,7);
                    s1x0 <= to_signed(15,8);
                    s2x0 <= to_signed(-5,8);
                    s1x1 <= to_signed(120,8);
                    s2x1 <= to_signed(120,8);
                    s1Color <= "01111";
                    s2Color <= "11100";
                    s1drawLineEn <= '1';
                    s2drawLineEn <= '1';
                    state := AddingScanlines1;
                when AddingScanlines1 =>
                    s1y <= to_unsigned(60,7);
                    s1x0 <= to_signed(60,8);
                    s1x1 <= to_signed(30,8);
                    s1Color <= "00111";
                    s1drawLineEn <= '1';
                    state := WaitingForRender;
                when WaitingForRender =>
                    if s1Empty and s2Empty then
                        countFpsEn <= '1';
                        state := FlippingBuffers;
                    end if;
                when FlippingBuffers =>
                    if not readingFromMemory then
                        bufferSelectInt <= not bufferSelectInt;
                        state := StartingClear;
                    end if;
            end case;
        end if;
    end process;

    WRITE_SELECT_SWITCH: process(clock)
    begin
        if rising_edge(clock) then
            scanlineWriteSelect <= not scanlineWriteSelect;
        end if;
    end process;

    -- Scanline drawers
    SCANLINE_GENERATOR_1: ScanlinePipeline port map(
        clock => clock,
        reset => reset,

        scanlineY => s1y,
        scanlineX0 => s1x0,
        scanlineX1 => s1x1,
        scanlineZ0 => (others => '0'),
        scanlineZ1 => (others => '0'),
        scanlineColor => s1color,
        scanlinePlotEn => s1drawLineEn,
        pipelineEmpty => s1Empty,
        onWriteCycle => scanlineWriteSelect,
        address => address1,
        writeData => entry1,
        readData => readData,
        plotEn => plot1
    );


    SCANLINE_GENERATOR_2: ScanlinePipeline port map(
        clock => clock,
        reset => reset,

        scanlineY => s2y,
        scanlineX0 => s2x0,
        scanlineX1 => s2x1,
        scanlineZ0 => (others => '0'),
        scanlineZ1 => (others => '0'),
        scanlineColor => s2color,
        scanlinePlotEn => s2drawLineEn,
        pipelineEmpty => s2Empty,
        onWriteCycle => not scanlineWriteSelect,
        address => address2,
        writeData => entry2,
        readData => readData,
        plotEn => plot2
    );

    -- Support logic for the renderer
    FRAME_CLEARER: process(clock)
    begin
        if rising_edge(clock) then
            if clearingBufferMode then
                if clearAddress = "111111111111" then
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

    READ_MUX: process(all)
    begin
        if scanlineWriteSelect then
            readAddress <= address1;
        else
            readAddress <= address2;
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
            if scanlineWriteSelect then
                writeEn <= plot2;
                writeData <= entry2;
                writeAddress <= address2;
            else
                writeEn <= plot1;
                writeData <= entry1;
                writeAddress <= address1;
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