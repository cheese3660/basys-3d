library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;

entity ScanlinePipeline is
    port(
        clock: in std_logic;
        reset: in std_logic;    

        scanlineY: in unsigned(6 downto 0);
        scanlineX0: in signed(7 downto 0);
        scanlineX1: in signed(7 downto 0);
        scanlineZ0: in signed(15 downto 0);
        scanlineZ1: in signed(15 downto 0);

        scanlineColor: in Color;

        scanlinePlotEn: in std_logic;

        onReadCycle: in std_logic;
        onWriteCycle: in std_logic;

        address: out std_logic_vector(13 downto 0);
        writeData: out FramebufferEntry;
        readData: in signed(15 downto 0);
        plotEn: out std_logic;

        pipelineEmpty: out std_logic;
        canAcceptScanline: out std_logic
    );
end ScanlinePipeline;


-- Let's do a simple pipelined architecture
architecture Procedural of ScanlinePipeline is

    -- Plotter values
    signal drawCanAccept: std_logic := '1';
    signal drawBegin: std_logic;

    -- Pipeline values
    constant COMPARE_STAGE: integer := 0;
    constant ARITHMETIC_STAGE: integer := COMPARE_STAGE+1;

    constant FIRST_STAGE: integer := COMPARE_STAGE;
    constant LAST_STAGE: integer := ARITHMETIC_STAGE;

    type x_array_t is array (FIRST_STAGE to LAST_STAGE) of signed(7 downto 0);
    type y_array_t is array (FIRST_STAGE to LAST_STAGE) of unsigned(6 downto 0);
    type z_array_t is array (FIRST_STAGE to LAST_STAGE) of signed(15 downto 0);
    type color_array_t is array (FIRST_STAGE to LAST_STAGE) of Color;
    type fixed16_array_t is array(FIRST_STAGE to LAST_STAGE) of signed(15 downto 0);
    type divisor_array_t is array(FIRST_STAGE to LAST_STAGE) of signed(7 downto 0);

    signal x0_pipeline: x_array_t;
    signal x1_pipeline: x_array_t;

    signal y_pipeline: y_array_t;
    signal z_pipeline: z_array_t;

    signal color_pipeline: color_array_t;

    signal z0_pipeline: fixed16_array_t; -- will hold z0 at the beginning
    signal z1_pipeline: fixed16_array_t; -- will hold z1 at the beginning

    signal stage_has_value: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');
    signal stage_can_accept: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');

    constant NO_VALUE: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');

    -- Divider types
    type scanline_associated_t is record
        x0: signed(7 downto 0);
        x1: signed(7 downto 0);
        y: unsigned(6 downto 0);
        z: signed(15 downto 0);
        lineColor: Color;
    end record;

    -- Divider values
    
    signal dividendIn: divider_array_t(0 to 0)(15 downto 0);
    signal divisorIn: divider_array_t(0 to 0)(7 downto 0);
    signal scanlineAssociatedIn: scanline_associated_t;
    signal quotientOut: divider_array_t(0 to 0)(15 downto 0);
    signal scanlineAssociatedOut: scanline_associated_t;
    signal divideHasValue: std_logic;

    signal divideEmpty: std_logic;
    signal divideCanAccept: std_logic;

    signal maskedAccept: std_logic;

    -- Divider redeclaration?
    component Divider is
        generic(
            dividendSize: integer;
            divisorSize: integer;
    
            -- dividendSize + dividendShift => quotient size (and pipeline length)
            dividendShift: integer;
    
            -- How many dividends are being computed in parallel
            dividendCount: integer;
    
            -- And how many divisors are being used (grouped evenly between them)
            divisorCount: integer;
    
            type associated_t
        );
    
        port(
            clock: in std_logic;
            reset: in std_logic;
    
            nextCanAccept: in std_logic;
    
            dividendsIn: in divider_array_t(0 to dividendCount-1)(dividendSize-1 downto 0);
            divisorsIn: in divider_array_t(0 to divisorCount-1)(divisorSize-1 downto 0);
            associatedIn: in associated_t;
            hasValue: in std_logic;
    
            quotientsOut: out divider_array_t(0 to dividendCount-1)(dividendSize+dividendShift - 1 downto 0);
            associatedOut: out associated_t;
            -- Active when the next stage can accept a value, and this actually has a value
            givingValue: out std_logic;
            -- Active always when this actually has a value
            hasValueInLastStage: out std_logic;
            canAccept: out std_logic;
            empty: out std_logic
        );
    end component;
begin
    

    -- Make it so the first stage can only accept when the further stages down can accept, and set up the initial inputs
    stage_has_value(COMPARE_STAGE) <= scanlinePlotEn;
    stage_can_accept(COMPARE_STAGE) <= stage_can_accept(ARITHMETIC_STAGE);
    canAcceptScanline <= stage_can_accept(COMPARE_STAGE);

    x0_pipeline(COMPARE_STAGE) <= scanlineX0;
    x1_pipeline(COMPARE_STAGE) <= scanlineX1;

    y_pipeline(COMPARE_STAGE) <= scanlineY;

    color_pipeline(COMPARE_STAGE) <= scanlineColor;

    z0_pipeline(COMPARE_STAGE) <= scanlineZ0;
    z1_pipeline(COMPARE_STAGE) <= scanlineZ1;

    PIPELINE_COMPARE: process(clock, reset) is
        variable x0: signed(7 downto 0);
        variable x1: signed(7 downto 0);
        variable z0: signed(15 downto 0);
        variable z1: signed(15 downto 0);
    begin
        if reset then
            stage_has_value(ARITHMETIC_STAGE) <= '0';
        elsif rising_edge(clock) then
            x0 := x0_pipeline(COMPARE_STAGE);
            x1 := x1_pipeline(COMPARE_STAGE);

            z0 := z0_pipeline(COMPARE_STAGE);
            z1 := z1_pipeline(COMPARE_STAGE);
            
            if x0 > x1 then
                x0 := x1;
                x1 := x0_pipeline(COMPARE_STAGE);
                z0 := z1;
                z1 := z0_pipeline(COMPARE_STAGE);
            end if;

            if stage_can_accept(ARITHMETIC_STAGE) and stage_has_value(COMPARE_STAGE) then
                x0_pipeline(ARITHMETIC_STAGE) <= x0;
                x1_pipeline(ARITHMETIC_STAGE) <= x1;

                y_pipeline(ARITHMETIC_STAGE) <= y_pipeline(COMPARE_STAGE);
                z_pipeline(ARITHMETIC_STAGE) <= z0;

                color_pipeline(ARITHMETIC_STAGE) <= color_pipeline(COMPARE_STAGE);

                z0_pipeline(ARITHMETIC_STAGE) <= z0;
                z1_pipeline(ARITHMETIC_STAGE) <= z1;

                -- This implies the line to be all the way off the screen, which is an easy pipeline removal
                if x1(7) then
                    report "REMOVING!";
                    stage_has_value(ARITHMETIC_STAGE) <= '0';
                else
                    stage_has_value(ARITHMETIC_STAGE) <= '1';
                end if;
            elsif stage_can_accept(ARITHMETIC_STAGE) and not stage_has_value(COMPARE_STAGE) then
                stage_has_value(ARITHMETIC_STAGE) <= '0';
            end if;
        end if;
    end process;


    stage_can_accept(ARITHMETIC_STAGE) <= (not stage_has_value(ARITHMETIC_STAGE)) or divideCanAccept;
    PIPELINE_ARITHMETIC: process(clock, reset) is
        variable z0: signed(15 downto 0);
        variable z1: signed(15 downto 0);
        variable zDiff: signed(15 downto 0);
        variable xDiff: signed(7 downto 0);
    begin
        if reset then
            divideHasValue <= '0';
        elsif rising_edge(clock) then
            z0 := z0_pipeline(ARITHMETIC_STAGE);
            z1 := z1_pipeline(ARITHMETIC_STAGE);
            zDiff := z1 - z0;
            xDiff := x1_pipeline(ARITHMETIC_STAGE) - x0_pipeline(ARITHMETIC_STAGE);
            if divideCanAccept and stage_has_value(ARITHMETIC_STAGE) then
                scanlineAssociatedIn.x0 <= x0_pipeline(ARITHMETIC_STAGE);
                scanlineAssociatedIn.x1 <= x1_pipeline(ARITHMETIC_STAGE);   
                scanlineAssociatedIn.y <= y_pipeline(ARITHMETIC_STAGE);
                scanlineAssociatedIn.z <= z_pipeline(ARITHMETIC_STAGE);
                scanlineAssociatedIn.lineColor <= color_pipeline(ARITHMETIC_STAGE);
                dividendIn(0) <= zDiff;
                divisorIn(0) <= xDiff;
                divideHasValue <= '1';
            elsif divideCanAccept and not stage_has_value(ARITHMETIC_STAGE) then
                divideHasValue <= '0';
            end if;
        end if;
    end process;

    maskedAccept <= drawCanAccept and not drawBegin;

    Z_DIVIDER: Divider generic map (
        dividendSize => 16,
        divisorSize => 8,
        dividendShift => 0,
        dividendCount => 1,
        divisorCount => 1,
        associated_t => scanline_associated_t
    ) port map (
        clock => clock,
        reset => reset,
        nextCanAccept => maskedAccept,
        dividendsIn => dividendIn,
        divisorsIn => divisorIn,
        associatedIn => scanlineAssociatedIn,
        hasValue => divideHasValue,
        quotientsOut => quotientOut,
        associatedOut => scanlineAssociatedOut,
        givingValue => drawBegin,
        canAccept => divideCanAccept,
        empty => divideEmpty
    );

    -- Plots one pixel to the framebuffer every 2 clock cycles (1 clock cycle is necessary for framebuffer calculations)
    DRAW: process(clock, reset) is
        variable x: unsigned(6 downto 0);
        variable maxX: unsigned(6 downto 0);
        variable y: unsigned(6 downto 0);
        variable currentColor: Color;
        variable z: signed(15 downto 0);
        variable zs: signed(15 downto 0);
        variable writing: boolean;
    begin
        if reset then
            drawCanAccept <= '1';
        elsif rising_edge(clock) then
            plotEn <= '0';
            writeData.color <= currentColor;
            writeData.depth <= z;
            address(13 downto 7) <= std_logic_vector(y);
            if not drawCanAccept then
                if writing then
                    if onWriteCycle then
                        if z < readData then
                            plotEn <= '1';
                        end if;
                        if x = maxX then
                            drawCanAccept <= '1';
                        else
                            x := x + 1;
                            z := z + zs;
                        end if;
                        writing := false;
                    end if;
                else
                    if onReadCycle then
                        address(6 downto 0) <= std_logic_vector(x);
                        writing := true;
                    end if;
                end if;
            elsif drawBegin then
                if not scanlineAssociatedOut.x0(7) then
                    x := unsigned(scanlineAssociatedOut.x0(6 downto 0));
                else
                    x := (others => '0');
                end if;
                if not scanlineAssociatedOut.x1(7) then
                    maxX := unsigned(scanlineAssociatedOut.x1(6 downto 0));
                else
                    maxX := (others => '0');
                end if;
                y := scanlineAssociatedOut.y;
                currentColor := scanlineAssociatedOut.lineColor;
                z := scanlineAssociatedOut.z;
                zs := quotientOut(0);
                writing := false;
                drawCanAccept <= '0';
            end if;
        end if;
    end process;


    EMPTY: process(drawCanAccept, stage_has_value, divideEmpty)
    begin
        if not drawCanAccept then
            pipelineEmpty <= '0';
        elsif stage_has_value = NO_VALUE then
            pipelineEmpty <= divideEmpty;
        else
            pipelineEmpty <= '0';
        end if;
    end process;
end Procedural;