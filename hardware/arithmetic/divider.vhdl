library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity Divider is        
    generic(
        dividendSize: integer;
        divisorSize: integer;

        -- dividendSize + dividendShift => quotient size (and pipeline length)
        dividendShift: integer;

        -- How many dividends are being computed in parallel
        dividendCount: integer;

        -- And how many divisors are being used (grouped evenly between them)
        divisorCount: integer;

        -- How many bits of division do we want to do per clock cycle, the dividendSize + dividendShift needs to divide this evenly
        bitsPerClockCycle: integer := 1;

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
end Divider;

architecture Generated of Divider is

    -- One for getting the sign of the result
    -- One for setting the sign of the result
    constant STAGE_COUNT: integer := dividendShift + dividendSize + 2;
    constant DIVIDER_STAGE_COUNT: integer := dividendShift + dividendSize;
    constant QUOTIENT_SIZE: integer := dividendShift + dividendSize;

    type quotient_sub_array_t is array(0 to dividendCount-1) of unsigned(QUOTIENT_SIZE - 1 downto 0);
    type quotient_array_t is array(0 to DIVIDER_STAGE_COUNT) of quotient_sub_array_t;
    
    -- I'm hoping that both of these get bits removed as necessary in synthesis
    signal quotient_array: quotient_array_t;

    type remainder_sub_array_t is array(0 to dividendCount-1) of unsigned(QUOTIENT_SIZE - 1 downto 0);
    type remainder_array_t is array(0 to DIVIDER_STAGE_COUNT) of remainder_sub_array_t;
    signal remainder_array: remainder_array_t;


    -- I'm hoping this gets trimmed as information gets lost at the end too, it should make for some smaller synthesis 
    type divisor_sub_array_t is array(0 to divisorCount-1) of unsigned(divisorSize - 1 downto 0);
    type divisor_array_t is array(0 to DIVIDER_STAGE_COUNT) of divisor_sub_array_t;

    signal divisor_array: divisor_array_t;

    type sign_array_t is array(0 to DIVIDER_STAGE_COUNT) of std_logic_vector(dividendCount-1 downto 0);

    signal sign_array: sign_array_t;

    type associated_array_t is array(0 to DIVIDER_STAGE_COUNT) of associated_t;

    signal associated_array: associated_array_t;

    constant NO_VALUE: std_logic_vector(STAGE_COUNT downto 0) := (others => '0');
    signal stageHasValue: std_logic_vector(STAGE_COUNT downto 0) := (others => '0');
    signal stageCanAccept: std_logic_vector(STAGE_COUNT-1 downto 0);


    constant GROUP_SIZE: integer := dividendCount/divisorCount;
begin

    canAccept <= stageCanAccept(0);

    stageHasValue(0) <= hasValue;
    -- The initial stage can accept
    stageCanAccept(0) <= (not hasValue) or stageCanAccept(1);
    GET_SIGN: process(clock, reset) is
        variable result: unsigned(QUOTIENT_SIZE-1 downto 0);
    begin
        if reset then
            stageHasValue(1) <= '0';
        elsif rising_edge(clock) then
            result := (others => '0');
            if stageCanAccept(1) then
                if stageHasValue(0) then
                    associated_array(0) <= associatedIn;

                    -- Compute the sign values, and absolute values of the dividends
                    for index in 0 to dividendCount-1 loop
                        sign_array(0)(index) <= dividendsIn(index)(dividendSize-1) xor divisorsIn(index/GROUP_SIZE)(divisorSize -1);
                        result := (others => '0');
                        if dividendShift > 0 then
                            result(dividendShift-1 downto 0) := (others => '0');
                        end if;

                        if dividendsIn(index)(dividendSize-1) then
                            result(QUOTIENT_SIZE-1 downto dividendShift) := unsigned(-dividendsIn(index));
                        else
                            result(QUOTIENT_SIZE-1 downto dividendShift) := unsigned(dividendsIn(index));
                        end if;
                        remainder_array(0)(index) <= result;
                    end loop;

                    -- Then perform the absolute values of the divisors
                    for index in 0 to divisorCount-1 loop
                        if divisorsIn(index)(divisorSize-1) then
                            divisor_array(0)(index) <= unsigned(-divisorsIn(index));
                        else
                            divisor_array(0)(index) <= unsigned(divisorsIn(index));
                        end if;
                    end loop;

                    stageHasValue(1) <= '1';
                else
                    stageHasValue(1) <= '0';
                end if;
            end if;
        end if;
    end process;

    G_DIV_STAGES: for stage in 1 to DIVIDER_STAGE_COUNT generate
        stageCanAccept(stage) <= (not stageHasValue(stage)) or stageCanAccept(stage+1);
        DIV: process(clock, reset) is
            constant SHIFTED_STAGE: integer range 0 to DIVIDER_STAGE_COUNT-1 := stage-1;
            constant QUOTIENT_STAGE: integer := stage-2;
            constant DIVISOR_SHIFT: integer := DIVIDER_STAGE_COUNT-stage;
            variable remainder_in: unsigned(QUOTIENT_SIZE - 1 downto 0);
            variable divisor_in: unsigned(divisorSize - 1 downto 0);
            variable subtraction_result: unsigned(divisorSize downto 0);
            variable remainder_portion: unsigned(divisorSize downto 0);
            variable quotient_bit: std_logic;

        begin
            if reset then
                stageHasValue(stage+1) <= '0';
            elsif rising_edge(clock) then
                remainder_in := (others => '0');
                divisor_in := (others => '0');
                subtraction_result := (others => '0');
                remainder_portion := (others => '0');
                quotient_bit := '0';
                if stageCanAccept(stage+1) then
                    if stageHasValue(stage) then
                        for index in 0 to dividendCount-1 loop
                            divisor_in := divisor_array(SHIFTED_STAGE)(index/GROUP_SIZE);
                            remainder_in := remainder_array(SHIFTED_STAGE)(index);
                            -- now let's do all the calculations using a single subtraction
                            if DIVISOR_SHIFT+divisorSize >= QUOTIENT_SIZE then
                                remainder_portion := (others => '0');
                                remainder_portion(stage-1 downto 0) := remainder_in(QUOTIENT_SIZE-1 downto DIVISOR_SHIFT);
                            else
                                remainder_portion := remainder_in(DIVISOR_SHIFT + divisorSize downto DIVISOR_SHIFT);
                            end if;
                            subtraction_result := remainder_portion - divisor_in;
                            -- If the value is positive, that means the value was removed successfully
                            quotient_bit := not subtraction_result(divisorSize);
                            -- If we aren't on the final stage, then we propagate the new remainder
                            if stage /= DIVIDER_STAGE_COUNT then
                                if quotient_bit then
                                    if DIVISOR_SHIFT+divisorSize >= QUOTIENT_SIZE then
                                        -- how is this out of range?
                                        remainder_array(SHIFTED_STAGE+1)(index)(DIVISOR_SHIFT-1 downto 0) <= remainder_in(DIVISOR_SHIFT-1 downto 0);
                                        remainder_array(SHIFTED_STAGE+1)(index)(QUOTIENT_SIZE-1 downto DIVISOR_SHIFT) <= subtraction_result(stage-1 downto 0);
                                    else
                                        remainder_array(SHIFTED_STAGE+1)(index)(DIVISOR_SHIFT-1 downto 0) <= remainder_in(DIVISOR_SHIFT-1 downto 0);
                                        remainder_array(SHIFTED_STAGE+1)(index)(DIVISOR_SHIFT + divisorSize downto DIVISOR_SHIFT) <= subtraction_result;
                                    end if;
                                else
                                    remainder_array(SHIFTED_STAGE+1)(index) <= remainder_in;
                                end if;
                            end if;
                            quotient_array(QUOTIENT_STAGE+1)(index)(DIVISOR_SHIFT) <= quotient_bit;
                            if stage > 1 then
                                quotient_array(QUOTIENT_STAGE+1)(index)(QUOTIENT_SIZE-1 downto QUOTIENT_SIZE - (stage - 1)) <= quotient_array(QUOTIENT_STAGE)(index)(QUOTIENT_SIZE-1 downto QUOTIENT_SIZE - (stage - 1));
                            end if;
                        end loop;
                        sign_array(SHIFTED_STAGE+1) <= sign_array(SHIFTED_STAGE);
                        associated_array(SHIFTED_STAGE+1) <= associated_array(SHIFTED_STAGE);
                        if stage /= DIVIDER_STAGE_COUNT then
                            divisor_array(SHIFTED_STAGE+1) <= divisor_array(SHIFTED_STAGE);
                        end if;
                        stageHasValue(stage+1) <= '1';
                    else
                        stageHasValue(stage+1) <= '0';
                    end if;
                end if;
            end if;
        end process;
    end generate;


    -- The final stage can accept
    stageCanAccept(STAGE_COUNT - 1) <= (not stageHasValue(STAGE_COUNT - 1)) or nextCanAccept;
    SET_SIGN: process(clock, reset) is
    begin
        if reset then
            stageHasValue(STAGE_COUNT) <= '0';
        elsif rising_edge(clock) then
            givingValue <= '0';
            if nextCanAccept then
                if stageHasValue(STAGE_COUNT-1) then
                    for index in 0 to dividendCount-1 loop
                        if sign_array(DIVIDER_STAGE_COUNT)(index) then
                            quotientsOut(index) <= -signed(quotient_array(DIVIDER_STAGE_COUNT-1)(index));
                        else
                            quotientsOut(index) <= signed(quotient_array(DIVIDER_STAGE_COUNT-1)(index));
                        end if;
                    end loop;
                    associatedOut <= associated_array(STAGE_COUNT-2);
                    givingValue <= '1';
                    stageHasValue(STAGE_COUNT) <= '1';
                else
                    stageHasValue(STAGE_COUNT) <= '0';
                end if;
            end if;
        end if;
    end process;

    hasValueInLastStage <= stageHasValue(STAGE_COUNT);

    EMPTY_GEN: process(stageHasValue) is
    begin
        if stageHasValue = NO_VALUE then
            empty <= '1';
        else
            empty <= '0';
        end if;
    end process;
end Generated ; -- Generated