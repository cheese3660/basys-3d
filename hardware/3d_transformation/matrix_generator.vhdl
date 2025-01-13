library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_arithmetic.all;


-- Calculates a transformation matrix of the form
-- /        cos(B)      0        sin(B) \
-- |  sin(A)sin(B) cos(A) -sin(A)cos(B) |
-- \ -cos(A)sin(B) sin(A)  cos(A)cos(B) /

entity MatrixGenerator is
    port(
        clock: in std_logic;
        reset: in std_logic;

        -- Rotation angle on the X axis
        thetaA: in signed(15 downto 0);

        -- Rotation angle on the Y axis
        thetaB: in signed(15 downto 0);

        beginGenerate: in std_logic;

        transformationMatrix: out Matrix16;
        generationDoneMode: out std_logic
    );
end MatrixGenerator;


architecture Procedural of MatrixGenerator is

    -- Trig calculator signals
    signal theta: signed(15 downto 0);
    signal operation: TrigCalcType;
    signal beginCalculation: std_logic;
    signal result: signed(15 downto 0);
    signal operationDoneMode: std_logic;
begin
    
    MATRIX_GEN: process(clock, reset)
        type state_t is (
            -- The matrix generator is waiting for a new input to generate the matrix from
            Waiting,

            -- The matrix generator is performing all the trig lookups
            BeginningCosA,
            WaitingForCosA,
            BeginningCosB,
            WaitingForCosB,
            BeginningSinA,
            WaitingForSinA,
            BeginningSinB,
            WaitingForSinB,

            -- The matrix generator is performing all the multiplications
            PerformingMultiplications,
            -- The matrix generator is outputting the new matrix
            OutputtingMatrix
        );

        variable state: state_t := Waiting;

        variable cosA: signed(15 downto 0);
        variable cosB: signed(15 downto 0);
        variable sinA: signed(15 downto 0);
        variable sinB: signed(15 downto 0);

        variable cosAsinB: signed(31 downto 0);
        variable cosAcosB: signed(31 downto 0);
        variable sinAcosB: signed(31 downto 0);
        variable sinAsinB: signed(31 downto 0);
    begin
        if reset then
            state := Waiting;
        elsif rising_edge(clock) then
            theta <= (others => '0');
            operation <= Sine;
            beginCalculation <= '0';
            generationDoneMode <= '0';
            case state is
                when Waiting =>
                    generationDoneMode <= '1';
                    if beginGenerate then
                        generationDoneMode <= '0';
                        theta <= thetaA;
                        operation <= Cosine;
                        beginCalculation <= '1';
                        state := BeginningCosA;
                    end if;
                when BeginningCosA =>
                    state := WaitingForCosA;
                when WaitingForCosA =>
                    if operationDoneMode then
                        cosA := result;
                        theta <= thetaB;
                        operation <= Cosine;
                        beginCalculation <= '1';
                        state := BeginningCosB;
                    end if;
                when BeginningCosB =>
                    state := WaitingForCosB;
                when WaitingForCosB =>
                    if operationDoneMode then
                        cosB := result;
                        theta <= thetaA;
                        operation <= Sine;
                        beginCalculation <= '1';
                        state := BeginningSinA;
                    end if;
                when BeginningSinA =>
                    state := WaitingForSinA;
                when WaitingForSinA =>
                    if operationDoneMode then
                        sinA := result;
                        theta <= thetaB;
                        operation <= Sine;
                        beginCalculation <= '1';
                        state := BeginningSinB;
                    end if;
                when BeginningSinB =>
                    state := WaitingForSinB;
                when WaitingForSinB =>
                    if operationDoneMode then
                        sinB := result;
                        state := PerformingMultiplications;
                    end if;
                when PerformingMultiplications =>
                    cosAcosB := cosA * cosB;
                    sinAsinB := sinA * sinB;
                    cosAsinB := cosA * sinB;
                    sinAcosB := sinA * cosB;
                    state := OutputtingMatrix;
                when OutputtingMatrix =>
                    transformationMatrix <= (
                        Row1 => (                  cosB, (others => '0'),                   sinB),
                        Row2 => ( sinAsinB(23 downto 8),            cosA, -sinAcosB(23 downto 8)),
                        Row3 => (-cosAsinB(23 downto 8),            sinA,  cosAcosB(23 downto 8))
                    );
                    state := Waiting;
            end case;
        end if;
    end process;

    TRIG_CALC: TrigCalculator
    port map (
      clock             => clock,
      reset             => reset,
      theta             => theta,
      operation         => operation,
      beginCalculation  => beginCalculation,
      result            => result,
      operationDoneMode => operationDoneMode
    );
end architecture;