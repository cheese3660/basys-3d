library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;
use work.basys3d_rendering.all;


entity UpperHalfPipeline is
    Port(
        clock: in std_logic;
        reset: in std_logic;

        x1: in signed(15 downto 0);
        y1: in signed(7 downto 0);
        z1: in signed(15 downto 0);

        x2: in signed(15 downto 0);
        y2: in signed(7 downto 0);
        z2: in signed(15 downto 0);
    
        x3: in signed(15 downto 0);
        y3: in signed(7 downto 0);
        z3: in signed(15 downto 0);

        color: in std_logic_vector(4 downto 0);

        hasValue: in std_logic;
    
        readyMode: out std_logic;
        pipelineEmpty: out std_logic;

        onReadCycle: in std_logic;
        onWriteCycle: in std_logic;

        address: out std_logic_vector(13 downto 0);
        writeData: out FramebufferEntry;
        readData: in FramebufferEntry;
        plotEn: out std_logic
    );
end UpperHalfPipeline;

architecture Procedural of UpperHalfPipeline is

    type PipelineAssociated is record
        minX: signed(7 downto 0);
        maxX: signed(7 downto 0);
        startX: signed(15 downto 0);
        startZ: signed(15 downto 0);
        startY: signed(7 downto 0);
        endY: signed(7 downto 0);
        trigColor: std_logic_vector(4 downto 0);
    end record;

    -- Divider values
    signal dividendsIn: divider_array_t(0 to 3)(15 downto 0);
    signal divisorsIn: divider_array_t(0 to 1)(7 downto 0);
    signal associatedIn: PipelineAssociated;
    signal quotientsOut: divider_array_t(0 to 3)(15 downto 0);
    signal associatedOut: PipelineAssociated;
    signal divideHasValue: std_logic;

    signal divideIsGiving: std_logic;
    signal divideEmpty: std_logic;
    signal divideCanAccept: std_logic;

    -- Plotter values
    signal plotterReadyMode: std_logic;
    signal plotterEmpty: std_logic;

    -- Divider redeclaration because it otherwise crashes the simulator?
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

    readyMode <= divideCanAccept;

    FEED_CALCULATOR: process(clock,reset) is
    begin
        if reset then
            divideHasValue <= '0';
        elsif rising_edge(clocK) then
            if divideCanAccept then
                if hasValue then
                    dividendsIn(0) <= x2 - x1;
                    dividendsIn(1) <= z2 - z1;
                    divisorsIn(0) <= y2 - y1;

                    dividendsIn(2) <= x3 - x1;
                    dividendsIn(3) <= z3 - z1;
                    divisorsIn(1) <= y3 - y1;

                    associatedIn.minX <= minimum(x1(15 downto 8),minimum(x2(15 downto 8), x3(15 downto 8)));
                    associatedIn.maxX <= maximum(x1(15 downto 8),maximum(x2(15 downto 8), x3(15 downto 8)));
                    associatedIn.startX <= x1;
                    associatedIn.startZ <= z1;
                    associatedIn.startY <= y1;
                    associatedIn.endY <= y2;
                    associatedIn.trigColor <= color;

                    divideHasValue <= '1';
                else
                    divideHasValue <= '0';
                end if;
            end if;
        end if;
    end process;

    SLOPE_CALCULATOR: Divider generic map(
        dividendSize => 16,
        divisorSize => 8,
        dividendShift => 0,
        dividendCount => 4,
        divisorCount => 2,
        associated_t => PipelineAssociated
    ) port map (
        clock => clock,
        reset => reset,
        nextCanAccept => plotterReadyMode and not divideIsGiving,
        dividendsIn => dividendsIn,
        divisorsIn => divisorsIn,
        associatedIn => associatedIn,
        associatedOut => associatedOut,
        quotientsOut => quotientsOut,
        hasValue => divideHasValue,
        givingValue => divideIsGiving,
        canAccept => divideCanAccept,
        empty => divideEmpty
    );

    TRIANGLE_PLOTTER: UpperHalfPlotter port map(
        clock => clock,
        reset => reset,
        xSlope1 => quotientsOut(0),
        zSlope1 => quotientsOut(1),
        xSlope2 => quotientsOut(2),
        zSlope2 => quotientsOut(3),
        minX => associatedOut.minX,
        maxX => associatedOut.maxX,
        startX => associatedOut.startX,
        startZ => associatedOut.startZ,
        startY => associatedOut.startY,
        endY => associatedOut.endY,
        trigColor => associatedOut.trigColor,
        beginPlotEn => divideIsGiving,
        onReadCycle => onReadCycle,
        onWriteCycle => onWriteCycle,
        address => address,
        writeData => writeData,
        readData => readData,
        plotEn => plotEn,
        pipelineEmpty => plotterEmpty,
        readyMode => plotterReadyMode
    );

    pipelineEmpty <= divideEmpty and plotterEmpty and (not plotEn);
end Procedural;