-- This is the topmost level of the triangle pipeline, it will (for now) project then render a triangle, with transforming coming afterwards, using a lot of the DSP chips lmao

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;
use work.basys3d_rendering.all;


-- It will take in 3 points, and the normal vector of the triangle, transform them, then project them, then render it all to the framebuffer
entity TriangleRenderer is
    port(
        clock: in std_logic;
        reset: in std_logic;

        readyForTriangle: out std_logic;
        renderTriangleEn: in std_logic;

        point1: in Vector16;
        point2: in Vector16;
        point3: in Vector16;
        normal: in Vector16;

        lightDirection: in Vector16;

        worldToViewspace: in Matrix16;

        pipelineEmpty: out std_logic;

        writeAddress: out std_logic_vector(13 downto 0);
        writeData: out FramebufferEntry;
        readAddress: out std_logic_vector(13 downto 0);
        readData: in FramebufferEntry;
        writeEn: out std_logic
    );
    
end TriangleRenderer;

architecture Procedural of TriangleRenderer is
    -- Transformation variables
    signal multiplicationDoneMode: std_logic := '1';
    signal multiplicationStartEn: std_logic;
    signal luminanceDoneMode: std_logic := '1';
    signal luminanceStartEn: std_logic;

    signal transformationMatrix: Matrix16 := (others => (others => (others => '0')));
    signal transformPoint1: Vector16 := (others => (others => '0'));
    signal transformPoint2: Vector16 := (others => (others => '0'));
    signal transformPoint3: Vector16 := (others => (others => '0'));
    signal transformNormal: Vector16 := (others => (others => '0'));

    signal transformLightPos: Vector16 := (others => (others => '0'));
    signal transformedNormal: Vector16 := (others => (others => '0'));
    signal computedLightAmount: signed(15 downto 0) := (others => '0');

    -- Projector variables
    signal projectionBeginEn: std_logic;
    signal projectionDoneMode: std_logic;

    signal projectorA: Vector16 := (others => (others => '0'));
    signal projectorB: Vector16 := (others => (others => '0'));
    signal projectorC: Vector16 := (others => (others => '0'));

    signal projectorY1: signed(15 downto 0);
    signal projectorY2: signed(15 downto 0);
    signal projectorY3: signed(15 downto 0);

    -- Plotter variables
    signal plotterEmpty: std_logic;
    signal color: std_logic_vector(4 downto 0);
    signal plotTriangleEn: std_logic;
    signal plotterReadyMode: std_logic;

    signal plotterX1: signed(15 downto 0);
    signal plotterY1: signed(7 downto 0);
    signal plotterZ1: signed(15 downto 0);
    signal plotterX2: signed(15 downto 0);
    signal plotterY2: signed(7 downto 0);
    signal plotterZ2: signed(15 downto 0);
    signal plotterX3: signed(15 downto 0);
    signal plotterY3: signed(7 downto 0);
    signal plotterZ3: signed(15 downto 0);

    -- Pipeline signals
    signal controllerEmpty: std_logic;
begin
    pipelineEmpty <= plotterEmpty and controllerEmpty;

    CONTROLLER: process(clock, reset)
        type controller_state_t is (
            Waiting,
            BeginningTransformation,
            WaitingForTransformationToComplete,
            BeginningLuminanceCalculation,
            WaitingForLuminanceToComplete,
            BeginnningProjection,
            WaitingForProjectorToComplete,
            WaitingOnPlotter,
            BeginningPlot
        );
        variable state : controller_state_t := Waiting;
    begin
        if reset then
            state := Waiting;
        elsif rising_edge(clock) then
            readyForTriangle <= '0';
            multiplicationStartEn <= '0';
            projectionBeginEn <= '0';
            plotTriangleEn <= '0';
            controllerEmpty <= '0';
            case state is
                when Waiting =>
                    readyForTriangle <= '1';
                    controllerEmpty <= '1';
                    if renderTriangleEn then
                        transformationMatrix <= worldToViewspace;
                        transformPoint1 <= point1;
                        transformPoint2 <= point2;
                        transformPoint3 <= point3;
                        transformNormal <= normal;
                        transformLightPos <= lightDirection;
                        multiplicationStartEn <= '1';
                        state := BeginningTransformation;
                    end if;
                when BeginningTransformation =>
                    state := WaitingForTransformationToComplete;
                when WaitingForTransformationToComplete =>
                    if multiplicationDoneMode then
                        report "Finished transforming!";
                        report "A[" & to_string(real(to_integer(projectorA.X))/real(256)) & ", " & to_string(real(to_integer(projectorA.Y))/real(256)) & ", " & to_string(real(to_integer(projectorA.Z))/real(256)) & "]";
                        report "B[" & to_string(real(to_integer(projectorB.X))/real(256)) & ", " & to_string(real(to_integer(projectorB.Y))/real(256)) & ", " & to_string(real(to_integer(projectorB.Z))/real(256)) & "]";
                        report "C[" & to_string(real(to_integer(projectorC.X))/real(256)) & ", " & to_string(real(to_integer(projectorC.Y))/real(256)) & ", " & to_string(real(to_integer(projectorC.Z))/real(256)) & "]";
                        report "N[" & to_string(real(to_integer(transformedNormal.X))/real(256)) & ", " & to_string(real(to_integer(transformedNormal.Y))/real(256)) & ", " & to_string(real(to_integer(transformedNormal.Z))/real(256)) & "]";
                        if transformedNormal.Z(15) then
                            luminanceStartEn <= '1';
                            state := BeginningLuminanceCalculation;
                        else
                            state := Waiting;
                        end if;
                    end if;
                when BeginningLuminanceCalculation =>
                    state := WaitingForLuminanceToComplete;
                when WaitingForLuminanceToComplete =>
                    if luminanceDoneMode then
                        report "Computed luminance value of " & to_string(real(to_integer(computedLightAmount))/256);
                        projectionBeginEn <= '1';
                        state := BeginnningProjection;
                    end if;
                when BeginnningProjection =>
                    state := WaitingForProjectorToComplete;
                when WaitingForProjectorToComplete =>
                    if projectionDoneMode then
                        report "Finished projecting!";
                        report "A[" & to_string(to_integer(plotterX1) / 256) & ", " & to_string(to_integer(plotterY1)) & ", " & to_string(to_integer(plotterZ1)/256) & "]";
                        report "B[" & to_string(to_integer(plotterX2) / 256) & ", " & to_string(to_integer(plotterY2)) & ", " & to_string(to_integer(plotterZ2)/256) & "]";
                        report "C[" & to_string(to_integer(plotterX3) / 256) & ", " & to_string(to_integer(plotterY3)) & ", " & to_string(to_integer(plotterZ3)/256) & "]";
                        if plotterReadyMode then
                            color <= std_logic_vector(computedLightAmount(7 downto 3));
                            plotTriangleEn <= '1';
                            state := BeginningPlot;
                        else
                            state := WaitingOnPlotter;
                        end if;
                    end if;
                when WaitingOnPlotter =>
                    if plotterReadyMode then
                        color <= std_logic_vector(computedLightAmount(7 downto 3));
                        plotTriangleEn <= '1';
                        state := BeginningPlot;
                    else
                        state := WaitingOnPlotter;
                    end if;
                when BeginningPlot =>
                    state := Waiting;
            end case;
        end if;
    end process;

    LUMINANCE_CALCULATOR: process(clock, reset)
        type luminanceState is (
            SUMMING_FIRST,
            SUMMING_SECOND,
            INVERTING,
            CLAMPING_LOW,
            CLAMPING_HIGH
        );
        variable l1: signed(31 downto 0);
        variable l2: signed(31 downto 0);
        variable l3: signed(31 downto 0);
        variable s: luminanceState;
    begin
        if reset then
            luminanceDoneMode <= '1';
        elsif rising_edge(clock) then
            if luminanceDoneMode and luminanceStartEn then
                l1 := transformedNormal.X * lightDirection.X;
                l2 := transformedNormal.Y * lightDirection.Y;
                l3 := transformedNormal.Z * lightDirection.Z;
                s := SUMMING_FIRST;
                luminanceDoneMode <= '0';
            elsif not luminanceDoneMode then
                case s is
                    when SUMMING_FIRST =>
                        l2 := l2 + l3;
                        s := SUMMING_SECOND;
                    when SUMMING_SECOND =>
                        l1 := l1 + l2;
                        s := INVERTING;
                    when INVERTING =>
                        l1 := -l1;
                        s := CLAMPING_LOW;
                    when CLAMPING_LOW =>
                        l1 := maximum(l1,to_signed(0,32));
                        s := CLAMPING_HIGH;
                    when CLAMPING_HIGH =>
                        l1 := minimum(l1,to_signed(1 * 65536, 32));
                        computedLightAmount <= l1(23 downto 8);
                        luminanceDoneMode <= '1';

                end case;
            end if;
        end if;
    end process;

    TRANSFORMER: process(clock,reset)
        -- These are going to be all the variables to collapse

        -- Point 1 x Matrix
        variable p1x1 : signed(31 downto 0);
        variable p1x2 : signed(31 downto 0);
        variable p1x3 : signed(31 downto 0);

        variable p1y1 : signed(31 downto 0);
        variable p1y2 : signed(31 downto 0);
        variable p1y3 : signed(31 downto 0);

        variable p1z1 : signed(31 downto 0);
        variable p1z2 : signed(31 downto 0);
        variable p1z3 : signed(31 downto 0);
        
        -- Point 2 x Matrix
        variable p2x1 : signed(31 downto 0);
        variable p2x2 : signed(31 downto 0);
        variable p2x3 : signed(31 downto 0);

        variable p2y1 : signed(31 downto 0);
        variable p2y2 : signed(31 downto 0);
        variable p2y3 : signed(31 downto 0);

        variable p2z1 : signed(31 downto 0);
        variable p2z2 : signed(31 downto 0);
        variable p2z3 : signed(31 downto 0);
        
        -- Point 3 x matrix
        variable p3x1 : signed(31 downto 0);
        variable p3x2 : signed(31 downto 0);
        variable p3x3 : signed(31 downto 0);

        variable p3y1 : signed(31 downto 0);
        variable p3y2 : signed(31 downto 0);
        variable p3y3 : signed(31 downto 0);

        variable p3z1 : signed(31 downto 0);
        variable p3z2 : signed(31 downto 0);
        variable p3z3 : signed(31 downto 0);
        
        -- Normal
        variable nx1 : signed(31 downto 0);
        variable nx2 : signed(31 downto 0);
        variable nx3 : signed(31 downto 0);

        variable ny1 : signed(31 downto 0);
        variable ny2 : signed(31 downto 0);
        variable ny3 : signed(31 downto 0);

        variable nz1 : signed(31 downto 0);
        variable nz2 : signed(31 downto 0);
        variable nz3 : signed(31 downto 0);

        -- Sum state
        variable onSecondSum: boolean;
    begin
        if reset then
            multiplicationDoneMode <= '1';
        elsif rising_edge(clock) then
            if multiplicationDoneMode and multiplicationStartEn then
                -- Point 1
                p1x1 := transformPoint1.X * transformationMatrix.Row1.X;
                p1x2 := transformPoint1.Y * transformationMatrix.Row1.Y;
                p1x3 := transformPoint1.Z * transformationMatrix.Row1.Z;
                
                p1y1 := transformPoint1.X * transformationMatrix.Row2.X;
                p1y2 := transformPoint1.Y * transformationMatrix.Row2.Y;
                p1y3 := transformPoint1.Z * transformationMatrix.Row2.Z;
                
                p1z1 := transformPoint1.X * transformationMatrix.Row3.X;
                p1z2 := transformPoint1.Y * transformationMatrix.Row3.Y;
                p1z3 := transformPoint1.Z * transformationMatrix.Row3.Z;

                -- Point 2
                p2x1 := transformPoint2.X * transformationMatrix.Row1.X;
                p2x2 := transformPoint2.Y * transformationMatrix.Row1.Y;
                p2x3 := transformPoint2.Z * transformationMatrix.Row1.Z;
                
                p2y1 := transformPoint2.X * transformationMatrix.Row2.X;
                p2y2 := transformPoint2.Y * transformationMatrix.Row2.Y;
                p2y3 := transformPoint2.Z * transformationMatrix.Row2.Z;
                
                p2z1 := transformPoint2.X * transformationMatrix.Row3.X;
                p2z2 := transformPoint2.Y * transformationMatrix.Row3.Y;
                p2z3 := transformPoint2.Z * transformationMatrix.Row3.Z;

                -- Point 3
                p3x1 := transformPoint3.X * transformationMatrix.Row1.X;
                p3x2 := transformPoint3.Y * transformationMatrix.Row1.Y;
                p3x3 := transformPoint3.Z * transformationMatrix.Row1.Z;
                
                p3y1 := transformPoint3.X * transformationMatrix.Row2.X;
                p3y2 := transformPoint3.Y * transformationMatrix.Row2.Y;
                p3y3 := transformPoint3.Z * transformationMatrix.Row2.Z;
                
                p3z1 := transformPoint3.X * transformationMatrix.Row3.X;
                p3z2 := transformPoint3.Y * transformationMatrix.Row3.Y;
                p3z3 := transformPoint3.Z * transformationMatrix.Row3.Z;

                -- Normal
                nx1 := transformNormal.X * transformationMatrix.Row1.X;
                nx2 := transformNormal.Y * transformationMatrix.Row1.Y;
                nx3 := transformNormal.Z * transformationMatrix.Row1.Z;
                
                ny1 := transformNormal.X * transformationMatrix.Row2.X;
                ny2 := transformNormal.Y * transformationMatrix.Row2.Y;
                ny3 := transformNormal.Z * transformationMatrix.Row2.Z;
                
                nz1 := transformNormal.X * transformationMatrix.Row3.X;
                nz2 := transformNormal.Y * transformationMatrix.Row3.Y;
                nz3 := transformNormal.Z * transformationMatrix.Row3.Z;
                
                -- Luminance
                multiplicationDoneMode <= '0';
                onSecondSum := false;
            elsif not multiplicationDoneMode then
                -- We are doing the sums in 2 cycles because yeah, it might just be a better ide
                if onSecondSum then

                    -- point 1
                    p1x1 := p1x2 + p1x1;
                    p1y1 := p1y2 + p1y1;
                    p1z1 := p1z2 + p1z1;

                    projectorA <= (
                        X => signed(p1x1(23 downto 8)),
                        Y => signed(p1y1(23 downto 8)),
                        Z => signed(p1z1(23 downto 8))
                    );

                    -- point 2
                    p2x1 := p2x2 + p2x1;
                    p2y1 := p2y2 + p2y1;
                    p2z1 := p2z2 + p2z1;

                    projectorB <= (
                        X => signed(p2x1(23 downto 8)),
                        Y => signed(p2y1(23 downto 8)),
                        Z => signed(p2z1(23 downto 8))
                    );

                    -- point 3
                    p3x1 := p3x2 + p3x1;
                    p3y1 := p3y2 + p3y1;
                    p3z1 := p3z2 + p3z1;

                    projectorC <= (
                        X => signed(p3x1(23 downto 8)),
                        Y => signed(p3y1(23 downto 8)),
                        Z => signed(p3z1(23 downto 8))
                    );

                    -- normal
                    nx1 := nx2 + nx1;
                    ny1 := ny2 + ny1;
                    nz1 := nz2 + nz1;

                    transformedNormal <= (
                        X => signed(nx1(23 downto 8)),
                        Y => signed(ny1(23 downto 8)),
                        Z => signed(nz1(23 downto 8))
                    );

                    multiplicationDoneMode <= '1';
                else
                    -- point 1
                    p1x2 := p1x2 + p1x3;
                    p1y2 := p1y2 + p1y3;
                    p1z2 := p1z2 + p1z3;

                    -- point 2
                    p2x2 := p2x2 + p2x3;
                    p2y2 := p2y2 + p2y3;
                    p2z2 := p2z2 + p2z3;

                    -- point 3
                    p3x2 := p3x2 + p3x3;
                    p3y2 := p3y2 + p3y3;
                    p3z2 := p3z2 + p3z3;

                    -- normal
                    nx2 := nx2 + nx3;
                    ny2 := ny2 + ny3;
                    nz2 := nz2 + nz3;

                    onSecondSum := true;
                end if;
            end if;
        end if;
    end process;

    PROJECTOR: ProjectionCalculator generic map (
        -- Let's input a smaller Z' for these tests (default is 112)
        Z_PRIME => to_unsigned(integer(96*real(256)), 16)
    )
    port map (
      clock              => clock,
      reset              => reset,
      x1in               => projectorA.X,
      y1in               => projectorA.Y,
      z1in               => projectorA.Z,
      x2in               => projectorB.X,
      y2in               => projectorB.Y,
      z2in               => projectorB.Z,
      x3in               => projectorC.X,
      y3in               => projectorC.Y,
      z3in               => projectorC.Z,
      projectionBeginEn  => projectionBeginEn,
      x1out              => plotterX1,
      y1out              => projectorY1,
      z1out              => plotterZ1,
      x2out              => plotterX2,
      y2out              => projectorY2,
      z2out              => plotterZ2,
      x3out              => plotterX3,
      y3out              => projectorY3,
      z3out              => plotterZ3,
      projectionDoneMode => projectionDoneMode
    );

    plotterY1 <= projectorY1(15 downto 8);
    plotterY2 <= projectorY2(15 downto 8);
    plotterY3 <= projectorY3(15 downto 8);
    PLOTTER: TrianglePlotter
    port map (
      clock          => clock,
      reset          => reset,
      x1             => plotterX1,
      y1             => plotterY1,
      z1             => plotterZ1,
      x2             => plotterX2,
      y2             => plotterY2,
      z2             => plotterZ2,
      x3             => plotterX3,
      y3             => plotterY3,
      z3             => plotterZ3,
      color          => color,
      plotTriangleEn => plotTriangleEn,
      readyMode      => plotterReadyMode,
      pipelineEmpty  => plotterEmpty,
      writeAddress   => writeAddress,
      writeData      => writeData,
      readAddress    => readAddress,
      readData       => readData,
      writeEn        => writeEn
    );
end Procedural;