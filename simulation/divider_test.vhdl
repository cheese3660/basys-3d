library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

entity DividerTest is

end DividerTest;


architecture TB of DividerTest is
    
    -- Let's do it with a bunch of 32 bit divisions
    signal dividendIn: divider_array_t(0 to 0)(31 downto 0);
    signal divisorIn: divider_array_t(0 to 0)(31 downto 0);
    signal quotientOut: divider_array_t(0 to 0)(31 downto 0);

    type DivideInformation is record
        dividend: signed(31 downto 0);
        divisor: signed(31 downto 0);
        expected: signed(31 downto 0);
    end record DivideInformation;

    signal infoIn: DivideInformation;
    signal infoOut: DivideInformation;


    signal divideEn: std_logic;
    signal divisionDoneEn: std_logic;

    signal clock: std_logic;
    signal reset: std_logic;
begin

    CLOCK_RESET: process
    begin
        clock <= '0';
        reset <= '1';
        wait for 10 ns;
        reset <= '0';
        loop
            clock <= '0';
            wait for 5 ns;
            clock <= '1';
            wait for 5 ns;
        end loop;
    end process;

    UUT: Divider generic map (
        dividendSize => 32,
        divisorSize => 32,
        dividendShift => 0,
        dividendCount => 1,
        divisorCount => 1,
        associated_t => DivideInformation
    ) port map (
        clock => clock,
        reset => reset,
        nextCanAccept => '1',
        dividendsIn => dividendIn,
        divisorsIn => divisorIn,
        associatedIn => infoIn,
        hasValue => divideEn,
        quotientsOut => quotientOut,
        associatedOut => infoOut,
        givingValue => divisionDoneEn
    );

    FEED_DIVIDER: process
        procedure feed(
            constant a: in integer;
            constant b: in integer;
            signal info: out DivideInformation;
            signal dividend: out divider_array_t(0 to 0)(31 downto 0);
            signal divisor: out divider_array_t(0 to 0)(31 downto 0)
        ) is
            variable aSigned: signed(31 downto 0);
            variable bSigned: signed(31 downto 0);
            variable cSigned: signed(31 downto 0);
        begin
            aSigned := to_signed(a,32);
            bSigned := to_signed(b,32);
            cSigned := to_signed(a/b,32);
            info.dividend <= aSigned;
            info.divisor <= bSigned;
            info.expected <= cSigned;
            dividend(0) <= aSigned;
            divisor(0) <= bSigned;
        end procedure;
    begin
        wait until rising_edge(clock);
        feed(13245531,1523, infoIn, dividendIn, divisorIn);
        divideEn <= '1';
        wait until rising_edge(clock);
        feed(13245531,-1523, infoIn, dividendIn, divisorIn);
        divideEn <= '1';
        wait until rising_edge(clock);
        feed(-13245531,1523, infoIn, dividendIn, divisorIn);
        divideEn <= '1';
        wait until rising_edge(clock);
        feed(-13245531,-1523, infoIn, dividendIn, divisorIn);
        divideEn <= '1';
        wait until rising_edge(clock);
        feed(2_000_000_004,5, infoIn, dividendIn, divisorIn);
        divideEn <= '1';
        wait until rising_edge(clock);
        divideEn <= '0';
        wait;
    end process;

    REPORT_DIVIDER: process
    begin
        loop
            wait until rising_edge(clock);
            if divisionDoneEn then
                if quotientOut(0) = infoOut.expected then
                    report "PASS: " & to_string(to_integer(infoOut.dividend)) & "/" & to_string(to_integer(infoOut.divisor)) & " = " & to_string(to_integer(infoOut.expected)) & ", got: " & to_string(to_integer(quotientOut(0)));
                else
                    report "FAIL: " & to_string(to_integer(infoOut.dividend)) & "/" & to_string(to_integer(infoOut.divisor)) & " = " & to_string(to_integer(infoOut.expected)) & ", got: " & to_string(to_integer(quotientOut(0)));            
                end if;
            end if;
        end loop;
    end process;
end TB;