library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;


-- This will plot upper half triangles, given the precomputed information
entity UpperHalfPlotter is
    Port(
        clock: in std_logic;
        reset: in std_logic;

        xSlope1: in signed(15 downto 0);
        zSlope1: in signed(15 downto 0);
        xSlope2: in signed(15 downto 0);
        zSlope2: in signed(15 downto 0);
        
        minX: in signed(7 downto 0);
        maxX: in signed(7 downto 0);

        startX: in signed(15 downto 0);
        startZ: in signed(15 downto 0);

        startY: in signed(7 downto 0);
        endY: in signed(7 downto 0);

        trigColor: in std_logic_vector(4 downto 0);

        beginPlotEn: in std_logic;

        onWriteCycle: in std_logic;

        address: out std_logic_vector(13 downto 0);
        writeData: out FramebufferEntry;
        readData: in FramebufferEntry;
        plotEn: out std_logic;
        pipelineEmpty: out std_logic;
        readyMode: out std_logic
    );
end UpperHalfPlotter;

architecture Procedural of UpperHalfPlotter is
    signal readyForScanline: std_logic;
    
    signal scanlineY: unsigned(6 downto 0);
    
    signal scanlineX0: signed(7 downto 0);
    signal scanlineX1: signed(7 downto 0);

    signal scanlineZ0: signed(15 downto 0);
    signal scanlineZ1: signed(15 downto 0);

    signal scanlineColor: std_logic_vector(4 downto 0);

    signal startScanlineEn: std_logic;

    signal scanlinePipelineEmpty: std_logic;

    signal waitingMode: std_logic;
    
    type plotter_state_t is (
            Waiting, 
            ComparingAndClamping,
            WaitingOnScanline, 
            Adding
        );
begin
    
    TRIANGLE_PLOTTER: process(clock, reset)
        variable state: plotter_state_t := Waiting;
        variable xs1: signed(15 downto 0);
        variable zs1: signed(15 downto 0);
        variable xs2: signed(15 downto 0);
        variable zs2: signed(15 downto 0);
        variable min_x: signed(7 downto 0);
        variable max_x: signed(7 downto 0);
        variable x0: signed(15 downto 0);
        variable x1: signed(15 downto 0);
        variable cx0: signed(7 downto 0);
        variable cx1: signed(7 downto 0);
        variable z0: signed(15 downto 0);
        variable z1: signed(15 downto 0);
        variable y: signed(7 downto 0);
        variable maxY: signed(7 downto 0);

        variable color: std_logic_vector(4 downto 0);

        variable lastIter: boolean;
    begin
        if reset then
            state := Waiting;
        elsif rising_edge(clock) then
            waitingMode <= '0';
            scanlineY <= (others => '0');
            scanlineX0 <= (others => '0');
            scanlineX1 <= (others => '0');
            scanlineZ0 <= (others => '0');
            scanlineZ1 <= (others => '0');
            scanlineColor <= (others => '0');
            startScanlineEn <= '0';
            case state is
                when Waiting =>
                    waitingMode <= '1';
                    if beginPlotEn then
                        waitingMode <= '0';
                        xs1 := xSlope1;
                        zs1 := zSlope1;
                        xs2 := xSlope2;
                        zs2 := zSlope2;
                        min_x := minX;
                        max_x := maxX;
                        x0 := startX;
                        x1 := startX;
                        z0 := startZ;
                        z1 := startZ;
                        y := startY;
                        maxY := endY;
                        color := trigColor;
                        state := ComparingAndClamping;
                    end if;
                when ComparingAndClamping =>
                    lastIter := y = maxY;
                    if signed(x0(15 downto 8)) < min_x then
                        cx0 := min_x;
                    elsif signed(x0(15 downto 8)) > max_x then
                        cx0 := max_x;
                    else
                        cx0 := signed(x0(15 downto 8));
                    end if;

                    
                    if signed(x1(15 downto 8)) < min_x then
                        cx1 := min_x;
                    elsif signed(x1(15 downto 8)) > max_x then
                        cx1 := max_x;
                    else
                        cx1 := signed(x1(15 downto 8));
                    end if;
                        
                    if readyForScanline then
                        if not y(7) then
                            scanlineY <= unsigned(y(6 downto 0));
                            scanlineX0 <= cx0;
                            scanlineX1 <= cx1;
                            scanlineZ0 <= z0;
                            scanlineZ1 <= z1;
                            scanlineColor <= color;
                            startScanlineEn <= '1';
                        end if;
                        if lastIter then
                            state := Waiting;
                        else
                            state := Adding;
                        end if;
                    else
                        state := WaitingOnScanline;
                    end if;
                when WaitingOnScanline =>
                    if readyForScanline then
                        if not y(7) then
                            scanlineY <= unsigned(y(6 downto 0));
                            scanlineX0 <= cx0;
                            scanlineX1 <= cx1;
                            scanlineZ0 <= z0;
                            scanlineZ1 <= z1;
                            scanlineColor <= color;
                            startScanlineEn <= '1';
                        end if;
                        if lastIter then
                            state := Waiting;
                        else
                            state := Adding;
                        end if;
                    end if;
                when Adding =>
                    y := y + 1;
                    x0 := x0 + xs1;
                    x1 := x1 + xs1;
                    z0 := z0 + zs1;
                    z1 := z1 + zs1;
                    state := ComparingAndClamping;
            end case;
        end if;
    end process;


    SCANLINE_PLOTTER: ScanlinePipeline port map(
        clock => clock,
        reset => reset,
        scanlineY => scanlineY,
        scanlineX0 => scanlineX0,
        scanlineX1 => scanlineX1,
        scanlineZ0 => scanlineZ0,
        scanlineZ1 => scanlineZ1,
        scanlineColor => scanlineColor,
        scanlinePlotEn => startScanlineEn,
        onWriteCycle => onWriteCycle,
        address => address,
        writeData => writeData,
        readData => readData,
        plotEn => plotEn,
        pipelineEmpty => scanlinePipelineEmpty,
        canAcceptScanline => readyForScanline
    );

    pipelineEmpty <= waitingMode and scanlinePipelineEmpty;
    
    readyMode <= waitingMode;

end Procedural;