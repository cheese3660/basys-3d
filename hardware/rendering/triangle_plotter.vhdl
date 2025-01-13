-- Do I do pipelined math here?
-- That would end up with a lot of chip space (and mental effort) used for some small slope calculations, or do I accept a cost of ~96 clock cycles per triangle *here* (which the area of a half triangle can overtake)


-- I do pipelined math here, feeding into the 2 triangle pipelines


-- All of this will be tested by writing a *single* triangle over UART, then multiple

-- I could also write a testbench that reports positions and colors and then something in rust that will write said things, allowing me to debug the dang thing

-- That would be useful before connecting this to UART

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;

entity TrianglePlotter is
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

        plotTriangleEn: in std_logic;

        readyMode: out std_logic;
        pipelineEmpty: out std_logic;

        writeAddress: out std_logic_vector(13 downto 0);
        writeData: out FramebufferEntry;
        readAddress: out std_logic_vector(13 downto 0);
        readData: in FramebufferEntry;
        writeEn: out std_logic
    );
end TrianglePlotter;

architecture Procedural of TrianglePlotter is

    -- Pixel drawing signals
    signal address1: std_logic_vector(13 downto 0);
    signal entry1: FramebufferEntry;
    signal plot1: std_logic;
    signal address2: std_logic_vector(13 downto 0);
    signal entry2: FramebufferEntry;
    signal plot2: std_logic;

    -- Pipeline input signals

    -- Upper half pipeline
    signal x1upper: signed(15 downto 0);
    signal y1upper: signed(7 downto 0);
    signal z1upper: signed(15 downto 0);
    
    signal x2upper: signed(15 downto 0);
    signal y2upper: signed(7 downto 0);
    signal z2upper: signed(15 downto 0);

    signal x3upper: signed(15 downto 0);
    signal y3upper: signed(7 downto 0);
    signal z3upper: signed(15 downto 0);

    signal upperColor: std_logic_vector(4 downto 0);
    signal upperEn: std_logic;

    -- Lower half pipeline
    signal x1lower: signed(15 downto 0);
    signal y1lower: signed(7 downto 0);
    signal z1lower: signed(15 downto 0);
    
    signal x2lower: signed(15 downto 0);
    signal y2lower: signed(7 downto 0);
    signal z2lower: signed(15 downto 0);

    signal x3lower: signed(15 downto 0);
    signal y3lower: signed(7 downto 0);
    signal z3lower: signed(15 downto 0);

    signal lowerColor: std_logic_vector(4 downto 0);
    signal lowerEn: std_logic;

    -- Pipeline state signals
    signal upperReady: std_logic;
    signal upperEmpty: std_logic;
    
    signal lowerReady: std_logic;
    signal lowerEmpty: std_logic;

    signal triangleWaitingMode: std_logic;

    -- Divider signals
    signal dividend: unsigned(15 downto 0);
    signal divisor: unsigned(7 downto 0);
    signal dividerStartEn: std_logic;

    signal dividerDoneMode: std_logic;
    signal quotient: unsigned(15 downto 0);

    -- Triangle selection logic

    type TriangleSelectState is (
        ReadLowerWriteUpper,
        ReadUpper,
        WriteLower
    );

    signal currentSelectionState: TriangleSelectState := ReadLowerWriteUpper;

    signal upperOnReadCycle: std_logic;
    signal upperOnWriteCycle: std_logic;
    signal lowerOnReadCycle: std_logic;
    signal lowerOnWriteCycle: std_logic;
begin

    pipelineEmpty <= upperEmpty and lowerEmpty and triangleWaitingMode and not plotTriangleEn;

    PLOT_TRIANGLE: process(clock, reset)
        -- Temporary values
        variable tx: signed(15 downto 0);
        variable ty: signed(7 downto 0);
        variable tz: signed(15 downto 0);

        -- Temporary multiplication
        variable tm: signed(31 downto 0);

        -- Stored values (a is for ascending sort)
        -- x
        variable ax1: signed(15 downto 0);
        variable ax2: signed(15 downto 0);
        variable ax3: signed(15 downto 0);
        variable x4: signed(15 downto 0);
        
        -- y
        variable ay1: signed(7 downto 0);
        variable ay2: signed(7 downto 0);
        variable ay3: signed(7 downto 0);
        variable y4: signed(7 downto 0);

        -- z
        variable az1: signed(15 downto 0);
        variable az2: signed(15 downto 0);
        variable az3: signed(15 downto 0);
        variable z4: signed(15 downto 0);

        -- color
        variable storedColor: std_logic_vector(4 downto 0);

        -- State machine types

        type state_t is (
            -- The plotter is waiting to plot
            Waiting,
            -- The plotter is waiting to be able to send data to the upper half plotter
            WaitingOnUpperHalf, 
            -- The plotter is waiting to be able to send data to the lower half plotter
            WaitingOnLowerHalf,
            -- The plotter is beginning its Y division cycle
            BeginningYDivision,
            -- The plotter is performing the y division
            PerformingYDivision,
            -- The plotter is waiting to be able to send data to both the lower half plotter and upper half plotter
            WaitingOnBoth,
            -- The plotter is stalling for one clock cycle
            Stall
        );

        -- State machine variable
        variable state: state_t := Waiting;
    begin
        if reset then
            state := Waiting;
        elsif rising_edge(clock) then
            triangleWaitingMode <= '0';
            readyMode <= '0';
            
            tx := (others => '0');
            ty := (others => '0');
            tz := (others => '0');

            x1upper <= (others => '0');
            y1upper <= (others => '0');
            z1upper <= (others => '0');

            x2upper <= (others => '0');
            y2upper <= (others => '0');
            z2upper <= (others => '0');

            x3upper <= (others => '0');
            y3upper <= (others => '0');
            z3upper <= (others => '0');

            upperColor <= (others => '0');

            upperEn <= '0';

            x1lower <= (others => '0');
            y1lower <= (others => '0');
            z1lower <= (others => '0');

            x2lower <= (others => '0');
            y2lower <= (others => '0');
            z2lower <= (others => '0');

            x3lower <= (others => '0');
            y3lower <= (others => '0');
            z3lower <= (others => '0');

            lowerColor <= (others => '0');

            lowerEn <= '0';

            dividend <= (others => '0');
            divisor <= (others => '0');
            dividerStartEn <= '0';

            tm := (others => '0');

            case state is
                when Waiting =>
                    triangleWaitingMode <= '1';
                    readyMode <= '1';
                    if plotTriangleEn then
                        -- Store the parameters
                        ax1 := x1;
                        ax2 := x2;
                        ax3 := x3;
                        ay1 := y1;
                        ay2 := y2;
                        ay3 := y3;
                        az1 := z1;
                        az2 := z2;
                        az3 := z3;
                        storedColor := color;

                        -- Sort the parameters
                        if ay1 > ay2 then
                            tx := ax1;
                            ax1 := ax2;
                            ax2 := tx;

                            ty := ay1;
                            ay1 := ay2;
                            ay2 := ty;

                            tz := az1;
                            az1 := az2;
                            az2 := tz;
                        end if;

                        if ay1 > ay3 then
                            tx := ax1;
                            ax1 := ax3;
                            ax3 := tx;

                            ty := ay1;
                            ay1 := ay3;
                            ay3 := ty;

                            tz := az1;
                            az1 := az3;
                            az3 := tz;
                        end if;

                        if ay2 > ay3 then
                            tx := ax2;
                            ax2 := ax3;
                            ax3 := tx;

                            ty := ay2;
                            ay2 := ay3;
                            ay3 := ty;

                            tz := az2;
                            az2 := az3;
                            az3 := tz;
                        end if;

                        -- Perform dispatch
                        if ay2 = ay3 then
                            -- Check if we can dispatch now?
                            if upperReady and not upperEn then
                                -- Dispatch
                                x1upper <= ax1;
                                y1upper <= ay1;
                                z1upper <= az1;

                                x2upper <= ax2;
                                y2upper <= ay2;
                                z2upper <= az2;

                                x3upper <= ax3;
                                y3upper <= ay3;
                                z3upper <= az3;

                                upperColor <= storedColor;
                                
                                upperEn <= '1';
                                state := Stall;
                            else
                                -- We need to wait on dispatch
                                state := WaitingOnUpperHalf;
                            end if;
                        elsif ay1 = ay2 then
                            -- Check if we can dispatch now?
                            if lowerReady and not lowerEn then
                                -- Dispatch
                                x1lower <= ax1;
                                y1lower <= ay1;
                                z1lower <= az1;

                                x2lower <= ax2;
                                y2lower <= ay2;
                                z2lower <= az2;

                                x3lower <= ax3;
                                y3lower <= ay3;
                                z3lower <= az3;

                                lowerColor <= storedColor;
                                
                                lowerEn <= '1';
                                state := Stall;
                            else
                                -- We need to watit on dispatch
                                state := WaitingOnLowerHalf;
                            end if;
                        else
                            -- We now need to divide instead
                            state := BeginningYDivision;
                        end if;
                    end if;
                when WaitingOnUpperHalf =>
                    if upperReady then
                        -- Dispatch
                        x1upper <= ax1;
                        y1upper <= ay1;
                        z1upper <= az1;

                        x2upper <= ax2;
                        y2upper <= ay2;
                        z2upper <= az2;

                        x3upper <= ax3;
                        y3upper <= ay3;
                        z3upper <= az3;

                        upperColor <= storedColor;
                        
                        upperEn <= '1';

                        state := Stall;
                    end if;
                when WaitingOnLowerHalf =>
                    if lowerReady then
                        -- Dispatch
                        x1lower <= ax1;
                        y1lower <= ay1;
                        z1lower <= az1;

                        x2lower <= ax2;
                        y2lower <= ay2;
                        z2lower <= az2;

                        x3lower <= ax3;
                        y3lower <= ay3;
                        z3lower <= az3;

                        lowerColor <= storedColor;
                        
                        lowerEn <= '1';
                        state := Stall;
                    end if;
                when BeginningYDivision =>
                    dividend(15 downto 8) <= unsigned(ay2 - ay1);
                    divisor <= unsigned(ay3 - ay1);
                    dividerStartEn <= '1';
                    state := PerformingYDivision;
                when PerformingYDivision =>
                    if dividerDoneMode and not dividerStartEn then
                        tm := signed(quotient) * (ax3 - ax1);
                        x4 := tm(23 downto 8) + ax1;
                        tm := signed(quotient) * (az3 - az1);
                        z4 := tm(23 downto 8) + az1;
                        y4 := ay2;
                        if upperReady and lowerReady then
                            x1upper <= ax1;
                            y1upper <= ay1;
                            z1upper <= az1;
    
                            x2upper <= ax2;
                            y2upper <= ay2;
                            z2upper <= az2;
    
                            x3upper <= x4;
                            y3upper <= y4;
                            z3upper <= z4;
    
                            upperColor <= storedColor;
                            
                            upperEn <= '1';
                            
                            x1lower <= ax2;
                            y1lower <= ay2;
                            z1lower <= az2;

                            x2lower <= x4;
                            y2lower <= y4;
                            z2lower <= z4;

                            x3lower <= ax3;
                            y3lower <= ay3;
                            z3lower <= az3;

                            lowerColor <= storedColor;
                            
                            lowerEn <= '1';
                            state := Stall;
                        else
                            state := WaitingOnBoth;
                        end if;
                    end if;
                when WaitingOnBoth =>
                    if upperReady and lowerReady then
                        x1upper <= ax1;
                        y1upper <= ay1;
                        z1upper <= az1;

                        x2upper <= ax2;
                        y2upper <= ay2;
                        z2upper <= az2;

                        x3upper <= x4;
                        y3upper <= y4;
                        z3upper <= z4;

                        upperColor <= storedColor;
                        
                        upperEn <= '1';
                        
                        x1lower <= ax2;
                        y1lower <= ay2;
                        z1lower <= az2;

                        x2lower <= x4;
                        y2lower <= y4;
                        z2lower <= z4;

                        x3lower <= ax3;
                        y3lower <= ay3;
                        z3lower <= az3;

                        lowerColor <= storedColor;
                        
                        lowerEn <= '1';
                        state := Stall;
                    end if;
                when Stall =>
                    state := Waiting;
            end case;
        end if;
    end process;

    Y_DIVIDER: process(clock, reset)
        variable shift: integer range 0 to 15;
        variable remainder: unsigned(15 downto 0);
        variable subtract: unsigned(7 downto 0);
        variable remainder_portion: unsigned(8 downto 0);
        variable subtraction_result: unsigned(8 downto 0);
        variable quotient_bit: std_logic;
    begin
        if reset then
            dividerDoneMode <= '1';
        elsif rising_edge(clock) then
            remainder_portion := (others => '0');
            subtraction_result := (others => '0');
            quotient_bit := '0';
            if not dividerDoneMode then
                if shift+8 > 15 then
                    remainder_portion((15 - shift) downto 0) := remainder(15 downto shift);
                else
                    remainder_portion := remainder(shift+8 downto shift);
                end if;
                subtraction_result := remainder_portion - subtract;
                quotient_bit := not subtraction_result(8);
                if quotient_bit then
                    if shift+8 > 15 then
                        remainder(15 downto shift) := subtraction_result((15 - shift) downto 0);
                    else
                        remainder(shift+8 downto shift) := subtraction_result;
                    end if;
                end if;
                quotient(shift) <= quotient_bit;
                if shift = 0 then
                    dividerDoneMode <= '1';
                else
                    shift := shift - 1;
                end if;
            elsif dividerStartEn then
                shift := 15;
                remainder := dividend;
                subtract := divisor;
                dividerDoneMode <= '0';
            end if;
        end if;
    end process;

    -- Simple 3 state system for the mux switching
    WRITE_SELECT_SWITCH: process(clock)
    begin
        if rising_edge(clock) then
            case currentSelectionState is
                when ReadLowerWriteUpper =>
                    currentSelectionState <= ReadUpper;
                when ReadUpper =>
                    currentSelectionState <= WriteLower;
                when WriteLower =>
                    currentSelectionState <= ReadLowerWriteUpper;
            end case;
        end if;
    end process;

    MEMORY_MUX: process(all)
    begin
        case currentSelectionState is
            when ReadLowerWriteUpper =>
                upperOnReadCycle <= '0';
                upperOnWriteCycle <= '1';
                lowerOnReadCycle <= '1';
                lowerOnWriteCycle <= '0';

                -- Now do this assuming that we are coming from the previous cycle
                readAddress <= (others => '0');
                writeAddress <= address2;
                writeData <= entry2;
                writeEn <= plot2;
            when ReadUpper =>
                upperOnReadCycle <= '1';
                upperOnWriteCycle <= '0';
                lowerOnReadCycle <= '0';
                lowerOnWriteCycle <= '0';

                -- Now do this assuming that we are coming from the previous cycle
                readAddress <= address2;
                writeAddress <= address1;
                writeData <= entry1;
                writeEn <= plot1;
            
            when WriteLower =>
                upperOnReadCycle <= '0';
                upperOnWriteCycle <= '0';
                lowerOnReadCycle <= '0';
                lowerOnWriteCycle <= '1';

                -- Now do this assuming that we are coming from the previous cycle
                readAddress <= address1;
                writeAddress <= (others => '0');
                writeData <= (
                    depth => (others => '0'),
                    color => (others => '0')
                );
                writeEn <= '0';
        end case;
    end process;

    UPPER_HALF: UpperHalfPipeline port map(
        clock => clock,
        reset => reset,
        
        x1 => x1upper,
        y1 => y1upper,
        z1 => z1upper,

        x2 => x2upper,
        y2 => y2upper,
        z2 => z2upper,

        x3 => x3upper,
        y3 => y3upper,
        z3 => z3upper,

        color => upperColor,

        hasValue => upperEn,

        readyMode => upperReady,

        onReadCycle => upperOnReadCycle,
        onWriteCycle => upperOnWriteCycle,
        address => address1,
        writeData => entry1,
        readData => readData,
        plotEn => plot1,
        pipelineEmpty => upperEmpty
    );

    LOWER_HALF: LowerHalfPipeline port map(
        clock => clock,
        reset => reset,
        
        x1 => x1lower,
        y1 => y1lower,
        z1 => z1lower,

        x2 => x2lower,
        y2 => y2lower,
        z2 => z2lower,

        x3 => x3lower,
        y3 => y3lower,
        z3 => z3lower,

        color => lowerColor,

        hasValue => lowerEn,

        readyMode => lowerReady,

        onReadCycle => lowerOnReadCycle,
        onWriteCycle => lowerOnWriteCycle,
        
        address => address2,
        writeData => entry2,
        readData => readData,
        plotEn => plot2,
        pipelineEmpty => lowerEmpty
    );
end Procedural;