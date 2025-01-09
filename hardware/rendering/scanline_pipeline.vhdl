library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity ScanlinePipeline is
    port(
        clock: in std_logic;
        reset: in std_logic;    

        scanlineY: in unsigned(6 downto 0);
        scanlineX0: in signed(7 downto 0);
        scanlineX1: in signed(7 downto 0);
        scanlineZ0: in signed(15 downto 0);
        scanlineZ1: in signed(15 downto 0);

        scanlineColor: in std_logic_vector(4 downto 0);

        scanlinePlotEn: in std_logic;

        pixelInfo: out PixelEntry;
        plotEn: out std_logic;

        pipelineEmpty: out std_logic;
        canAcceptScanline: out std_logic
    );
end ScanlinePipeline;


-- Let's do a simple pipelined architecture
architecture Procedural of ScanlinePipeline is

    -- Plotter values
    signal drawCanAccept: std_logic := '1';
    signal drawZ: signed(15 downto 0);
    signal drawZStep: signed(15 downto 0);
    signal drawX0: signed(7 downto 0);
    signal drawX1: signed(7 downto 0);
    signal drawY: unsigned(6 downto 0);
    signal drawColor: std_logic_vector(4 downto 0);
    signal drawBegin: std_logic;

    -- Pipeline values
    constant COMPARE_STAGE: integer := 0;
    constant ARITHMETIC_STAGE: integer := COMPARE_STAGE+1;
    constant GET_SIGN_STAGE: integer := ARITHMETIC_STAGE+1;
    constant DIV_STAGE_0: integer := GET_SIGN_STAGE+1;
    constant DIV_STAGE_1: integer := DIV_STAGE_0+1;
    constant DIV_STAGE_2: integer := DIV_STAGE_1+1;
    constant DIV_STAGE_3: integer := DIV_STAGE_2+1;
    constant DIV_STAGE_4: integer := DIV_STAGE_3+1;
    constant DIV_STAGE_5: integer := DIV_STAGE_4+1;
    constant DIV_STAGE_6: integer := DIV_STAGE_5+1;
    constant DIV_STAGE_7: integer := DIV_STAGE_6+1;
    constant DIV_STAGE_8: integer := DIV_STAGE_7+1;
    constant DIV_STAGE_9: integer := DIV_STAGE_8+1;
    constant DIV_STAGE_A: integer := DIV_STAGE_9+1;
    constant DIV_STAGE_B: integer := DIV_STAGE_A+1;
    constant DIV_STAGE_C: integer := DIV_STAGE_B+1;
    constant DIV_STAGE_D: integer := DIV_STAGE_C+1;
    constant DIV_STAGE_E: integer := DIV_STAGE_D+1;
    constant DIV_STAGE_F: integer := DIV_STAGE_E+1;
    constant SET_SIGN_STAGE: integer := DIV_STAGE_F+1;

    constant FIRST_STAGE: integer := COMPARE_STAGE;
    constant LAST_STAGE: integer := SET_SIGN_STAGE;

    type x_array_t is array (FIRST_STAGE to LAST_STAGE) of signed(7 downto 0);
    type y_array_t is array (FIRST_STAGE to LAST_STAGE) of unsigned(6 downto 0);
    type z_array_t is array (FIRST_STAGE to LAST_STAGE) of signed(15 downto 0);
    type color_array_t is array (FIRST_STAGE to LAST_STAGE) of std_logic_vector(4 downto 0);
    type fixed16_array_t is array(FIRST_STAGE to LAST_STAGE) of unsigned(15 downto 0);
    type divisor_array_t is array(FIRST_STAGE to LAST_STAGE) of unsigned(7 downto 0);

    signal x0_pipeline: x_array_t;
    signal x1_pipeline: x_array_t;

    signal y_pipeline: y_array_t;
    signal z_pipeline: z_array_t;

    signal color_pipeline: color_array_t;

    signal quotient_pipeline: fixed16_array_t; -- will hold z0 at the beginning
    signal remainder_pipeline: fixed16_array_t; -- will hold z1 at the beginning
    signal divisor_pipeline: divisor_array_t;

    signal sign_pipeline: std_logic_vector(LAST_STAGE downto FIRST_STAGE);

    signal stage_has_value: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');
    signal stage_can_accept: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');

    constant NO_VALUE: std_logic_vector(LAST_STAGE downto FIRST_STAGE) := (others => '0');

    -- Pipeline processes

    procedure PerformDivisionPipelineStep(
        constant stage: in integer;
        constant quotient_bit: in integer;
        
        signal can_accept: in std_logic_vector;
        signal has_value: inout std_logic_vector;
        signal x0: inout x_array_t;
        signal x1: inout x_array_t;
        signal y: inout y_array_t;
        signal z: inout z_array_t;
        signal color: inout color_array_t;
        
        signal quotient: inout fixed16_array_t;
        signal remainder: inout fixed16_array_t;
        signal divisor: inout divisor_array_t;

        signal sgn: inout std_logic_vector
    ) is
        variable shifted_divisor: unsigned(15 downto 0);
    begin
        shifted_divisor := (others => '0');
        if quotient_bit >= 7 then
            shifted_divisor(quotient_bit downto quotient_bit-7) := divisor(stage);
        elsif quotient_bit >= 1 then
            shifted_divisor(quotient_bit downto 0) := divisor(stage)(7 downto (7 - quotient_bit));
        else
            shifted_divisor(0) := divisor(stage)(7);
        end if;

        if can_accept(stage+1) and has_value(stage) then
            x0(stage+1) <= x0(stage);
            x1(stage+1) <= x1(stage);
            y(stage+1) <= y(stage);
            z(stage+1) <= z(stage);
            color(stage+1) <= color(stage);
            sgn(stage+1) <= sgn(stage);
            divisor(stage+1) <= divisor(stage);

            if quotient_bit = 14 then
                quotient(stage+1)(15) <= quotient(stage)(15);    
            elsif quotient_bit < 14 then
                quotient(stage+1)(15 downto (quotient_bit+1)) <= quotient(stage)(15 downto (quotient_bit+1));
            end if;

            if remainder(stage) >= shifted_divisor then
                remainder(stage+1) <= remainder(stage) - shifted_divisor;
                quotient(stage+1)(quotient_bit) <= '1';
            else
                remainder(stage+1) <= remainder(stage);
                quotient(stage+1)(quotient_bit) <= '0';
            end if;

            has_value(stage+1) <= '1';
        elsif can_accept(stage+1) and not has_value(stage) then
            has_value(stage+1) <= '0';
        end if;
    end procedure;

begin
    

    -- Make it so the first stage can only accept when the further stages down can accept, and set up the initial inputs
    stage_has_value(COMPARE_STAGE) <= scanlinePlotEn;
    stage_can_accept(COMPARE_STAGE) <= stage_can_accept(ARITHMETIC_STAGE);
    canAcceptScanline <= stage_can_accept(COMPARE_STAGE);

    x0_pipeline(COMPARE_STAGE) <= scanlineX0;
    x1_pipeline(COMPARE_STAGE) <= scanlineX1;

    y_pipeline(COMPARE_STAGE) <= scanlineY;

    color_pipeline(COMPARE_STAGE) <= scanlineColor;

    quotient_pipeline(COMPARE_STAGE) <= unsigned(scanlineZ0);
    remainder_pipeline(COMPARE_STAGE) <= unsigned(scanlineZ1);

    PIPELINE_COMPARE: process(clock, reset) is
        variable x0: signed(7 downto 0);
        variable x1: signed(7 downto 0);
        variable z0: unsigned(15 downto 0);
        variable z1: unsigned(15 downto 0);
    begin
        if reset then
            stage_has_value(ARITHMETIC_STAGE) <= '0';
        elsif rising_edge(clock) then
            x0 := x0_pipeline(COMPARE_STAGE);
            x1 := x1_pipeline(COMPARE_STAGE);

            z0 := quotient_pipeline(COMPARE_STAGE);
            z1 := remainder_pipeline(COMPARE_STAGE);
            
            if x0 > x1 then
                x0 := x1;
                x1 := x0_pipeline(COMPARE_STAGE);
                z0 := z1;
                z1 := quotient_pipeline(COMPARE_STAGE);
            end if;

            if stage_can_accept(ARITHMETIC_STAGE) and stage_has_value(COMPARE_STAGE) then
                x0_pipeline(ARITHMETIC_STAGE) <= x0;
                x1_pipeline(ARITHMETIC_STAGE) <= x1;

                y_pipeline(ARITHMETIC_STAGE) <= y_pipeline(COMPARE_STAGE);
                z_pipeline(ARITHMETIC_STAGE) <= signed(z0);

                color_pipeline(ARITHMETIC_STAGE) <= color_pipeline(COMPARE_STAGE);

                quotient_pipeline(ARITHMETIC_STAGE) <= z0;
                remainder_pipeline(ARITHMETIC_STAGE) <= z1;

                -- This implies the line to be all the way off the screen, which is an easy pipeline removal
                if x1(7) then
                    stage_has_value(ARITHMETIC_STAGE) <= '0';
                else
                    stage_has_value(ARITHMETIC_STAGE) <= '1';
                end if;
            elsif stage_can_accept(ARITHMETIC_STAGE) and not stage_has_value(COMPARE_STAGE) then
                stage_has_value(ARITHMETIC_STAGE) <= '0';
            end if;
        end if;
    end process;


    stage_can_accept(ARITHMETIC_STAGE) <= (not stage_has_value(ARITHMETIC_STAGE)) or stage_can_accept(GET_SIGN_STAGE);
    PIPELINE_ARITHMETIC: process(clock, reset) is
        variable z0: signed(15 downto 0);
        variable z1: signed(15 downto 0);
        variable zDiff: signed(15 downto 0);
        variable xDiff: signed(7 downto 0);
    begin
        if reset then
            stage_has_value(GET_SIGN_STAGE) <= '0';
        elsif rising_edge(clock) then
            z0 := signed(quotient_pipeline(ARITHMETIC_STAGE));
            z1 := signed(remainder_pipeline(ARITHMETIC_STAGE));
            zDiff := z1 - z0;
            xDiff := x1_pipeline(ARITHMETIC_STAGE) - x0_pipeline(ARITHMETIC_STAGE);
            if stage_can_accept(GET_SIGN_STAGE) and stage_has_value(ARITHMETIC_STAGE) then
                x0_pipeline(GET_SIGN_STAGE) <= x0_pipeline(ARITHMETIC_STAGE);
                x1_pipeline(GET_SIGN_STAGE) <= x1_pipeline(ARITHMETIC_STAGE);   
                y_pipeline(GET_SIGN_STAGE) <= y_pipeline(ARITHMETIC_STAGE);
                z_pipeline(GET_SIGN_STAGE) <= z_pipeline(ARITHMETIC_STAGE);
                color_pipeline(GET_SIGN_STAGE) <= color_pipeline(ARITHMETIC_STAGE);
                remainder_pipeline(GET_SIGN_STAGE) <= unsigned(zDiff);
                divisor_pipeline(GET_SIGN_STAGE) <= unsigned(xDiff);
                stage_has_value(GET_SIGN_STAGE) <= '1';
            elsif stage_can_accept(GET_SIGN_STAGE) and not stage_has_value(ARITHMETIC_STAGE) then
                stage_has_value(GET_SIGN_STAGE) <= '0';
            end if;
        end if;
    end process;

    stage_can_accept(GET_SIGN_STAGE) <= (not stage_has_value(GET_SIGN_STAGE)) or stage_can_accept(DIV_STAGE_0);
    PIPELINE_GET_SIGN: process(clock, reset) is
        variable signed_divisor: signed(7 downto 0);
        variable signed_remainder: signed(15 downto 0);
        variable sign_bit: std_logic;
    begin
        if reset  then
            stage_has_value(DIV_STAGE_0) <= '0';
        elsif rising_edge(clock) then
            signed_divisor := signed(divisor_pipeline(GET_SIGN_STAGE));
            signed_remainder := signed(remainder_pipeline(GET_SIGN_STAGE));
            sign_bit := signed_divisor(7) xor signed_remainder(15);

            if stage_can_accept(DIV_STAGE_0) and stage_has_value(GET_SIGN_STAGE) then
                x0_pipeline(DIV_STAGE_0) <= x0_pipeline(GET_SIGN_STAGE);
                x1_pipeline(DIV_STAGE_0) <= x1_pipeline(GET_SIGN_STAGE);   
                y_pipeline(DIV_STAGE_0) <= y_pipeline(GET_SIGN_STAGE);
                z_pipeline(DIV_STAGE_0) <= z_pipeline(GET_SIGN_STAGE);
                color_pipeline(DIV_STAGE_0) <= color_pipeline(GET_SIGN_STAGE);
                if signed_remainder(15) then
                    remainder_pipeline(DIV_STAGE_0) <= unsigned(-signed_remainder);
                else
                    remainder_pipeline(DIV_STAGE_0) <= remainder_pipeline(GET_SIGN_STAGE);
                end if;

                if signed_divisor(7) then
                    divisor_pipeline(DIV_STAGE_0) <= unsigned(-signed_divisor);
                else
                    divisor_pipeline(DIV_STAGE_0) <= divisor_pipeline(GET_SIGN_STAGE);
                end if;

                sign_pipeline(DIV_STAGE_0) <= sign_bit;

                stage_has_value(DIV_STAGE_0) <= '1';
            elsif stage_can_accept(DIV_STAGE_0) and not stage_has_value(GET_SIGN_STAGE) then
                stage_has_value(DIV_STAGE_0) <= '0';
            end if;
        end if;
    end process;

    PIPELINE_DIV_GEN: for stage in DIV_STAGE_0 to DIV_STAGE_F generate
        stage_can_accept(stage) <= (not stage_has_value(stage)) or stage_can_accept(stage+1);
        PIPELINE_DIV: process(clock, reset) is
        begin
            if reset then
                stage_has_value(stage+1) <= '0';
            else
                PerformDivisionPipelineStep(
                    stage,
                    15-(stage-DIV_STAGE_0),

                    stage_can_accept,
                    stage_has_value,
                    x0_pipeline,
                    x1_pipeline,
                    y_pipeline,
                    z_pipeline,
                    color_pipeline,
                    quotient_pipeline,
                    remainder_pipeline,
                    divisor_pipeline,
                    sign_pipeline
                );
            end if;
        end process;
    end generate;

    -- stage_can_accept(DIV_STAGE_0) <= (not stage_has_value(DIV_STAGE_0)) or stage_can_accept(DIV_STAGE_1);
    -- PIPELINE_DIV_0: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_1) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_0,
    --             15,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_1) <= (not stage_has_value(DIV_STAGE_1)) or stage_can_accept(DIV_STAGE_2);
    -- PIPELINE_DIV_1: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_2) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_1,
    --             14,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_2) <= (not stage_has_value(DIV_STAGE_2)) or stage_can_accept(DIV_STAGE_3);
    -- PIPELINE_DIV_2: process(clock, reset) is
    --     variable shifted_divisor: unsigned(15 downto 0);
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_3) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_2,
    --             13,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_3) <= (not stage_has_value(DIV_STAGE_3)) or stage_can_accept(DIV_STAGE_4);
    -- PIPELINE_DIV_3: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_4) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_3,
    --             12,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_4) <= (not stage_has_value(DIV_STAGE_4)) or stage_can_accept(DIV_STAGE_5);
    -- PIPELINE_DIV_4: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_5) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_4,
    --             11,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_5) <= (not stage_has_value(DIV_STAGE_5)) or stage_can_accept(DIV_STAGE_6);
    -- PIPELINE_DIV_5: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_6) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_5,
    --             10,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_6) <= (not stage_has_value(DIV_STAGE_6)) or stage_can_accept(DIV_STAGE_7);
    -- PIPELINE_DIV_6: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_7) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_6,
    --             9,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_7) <= (not stage_has_value(DIV_STAGE_7)) or stage_can_accept(DIV_STAGE_8);
    -- PIPELINE_DIV_7: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_8) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_7,
    --             8,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_8) <= (not stage_has_value(DIV_STAGE_8)) or stage_can_accept(DIV_STAGE_9);
    -- PIPELINE_DIV_8: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_9) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_8,
    --             7,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_9) <= (not stage_has_value(DIV_STAGE_9)) or stage_can_accept(DIV_STAGE_A);
    -- PIPELINE_DIV_9: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_A) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_9,
    --             6,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_A) <= (not stage_has_value(DIV_STAGE_A)) or stage_can_accept(DIV_STAGE_B);
    -- PIPELINE_DIV_A: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_B) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_A,
    --             5,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_B) <= (not stage_has_value(DIV_STAGE_B)) or stage_can_accept(DIV_STAGE_C);
    -- PIPELINE_DIV_B: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_C) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_B,
    --             4,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_C) <= (not stage_has_value(DIV_STAGE_C)) or stage_can_accept(DIV_STAGE_D);
    -- PIPELINE_DIV_C: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_D) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_C,
    --             3,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_D) <= (not stage_has_value(DIV_STAGE_D)) or stage_can_accept(DIV_STAGE_E);
    -- PIPELINE_DIV_D: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_E) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_D,
    --             2,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_E) <= (not stage_has_value(DIV_STAGE_E)) or stage_can_accept(DIV_STAGE_F);
    -- PIPELINE_DIV_E: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(DIV_STAGE_F) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_E,
    --             1,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    -- stage_can_accept(DIV_STAGE_F) <= (not stage_has_value(DIV_STAGE_F)) or stage_can_accept(SET_SIGN_STAGE);
    -- PIPELINE_DIV_F: process(clock, reset) is
    -- begin
    --     if reset  then
    --         stage_has_value(SET_SIGN_STAGE) <= '0';
    --     elsif rising_edge(clock) then
    --         PerformDivisionPipelineStep(
    --             DIV_STAGE_F,
    --             0,

    --             stage_can_accept,
    --             stage_has_value,
    --             x0_pipeline,
    --             x1_pipeline,
    --             y_pipeline,
    --             z_pipeline,
    --             color_pipeline,
    --             quotient_pipeline,
    --             remainder_pipeline,
    --             divisor_pipeline,
    --             sign_pipeline
    --         );
    --     end if;
    -- end process;

    stage_can_accept(SET_SIGN_STAGE) <= (not stage_has_value(SET_SIGN_STAGE)) or drawCanAccept;
    PIPELINE_SET_SIGN: process(clock, reset) is
    begin
        if rising_edge(clock) then
            if drawCanAccept and stage_has_value(SET_SIGN_STAGE) then
                drawZ <= z_pipeline(SET_SIGN_STAGE);
                if sign_pipeline(SET_SIGN_STAGE) then
                    drawZStep <= -signed(quotient_pipeline(SET_SIGN_STAGE));
                else
                    drawZStep <= signed(quotient_pipeline(SET_SIGN_STAGE));
                end if;

                drawX0 <= x0_pipeline(SET_SIGN_STAGE);
                drawX1 <= x1_pipeline(SET_SIGN_STAGE);
                drawY <= y_pipeline(SET_SIGN_STAGE);
                drawColor <= color_pipeline(SET_SIGN_STAGE);
                drawBegin <= '1';
            else
                drawZ <= (others => 'Z');
                drawZStep <= (others => 'Z');
                drawX0 <= (others => 'Z');
                drawX1 <= (others => 'Z');
                drawY <= (others => 'Z');
                drawColor <= (others => 'Z');
                drawBegin <= '0';
            end if;
        end if;
    end process;

    DRAW: process(clock, reset) is
        variable x: signed(7 downto 0);
        variable maxX: signed(7 downto 0);
        variable y: unsigned(6 downto 0);
        variable color: std_logic_vector(4 downto 0);
        variable z: signed(15 downto 0);
        variable zs: signed(15 downto 0);
    begin
        if reset then
            drawCanAccept <= '1';
        elsif rising_edge(clock) then
            plotEn <= '0';
            pixelInfo.color <= color;
            pixelInfo.z <= z;
            pixelInfo.address(13 downto 7) <= std_logic_vector(y);
            pixelInfo.address(6 downto 0) <= std_logic_vector(x(6 downto 0));
            if not drawCanAccept then
                if not x(7) then
                    plotEn <= '1';
                end if;

                if x = maxX then
                    drawCanAccept <= '1';
                else
                    x := x + 1;
                end if;
            elsif drawBegin then
                x := drawX0;
                maxX := drawX1;
                y := drawY;
                color := drawColor;
                z := drawZ;
                zs := drawZStep;
                drawCanAccept <= '0';
            end if;
        end if;
    end process;


    EMPTY: process(drawCanAccept, stage_has_value)
    begin
        if not drawCanAccept then
            pipelineEmpty <= '0';
        elsif stage_has_value = NO_VALUE then
            pipelineEmpty <= '1';
        else
            pipelineEmpty <= '0';
        end if;
    end process;
end Procedural;