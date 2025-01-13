library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ProjectionCalculator is
    generic(
        -- How far back we want to move the object, let's default to 64 units for our calculations (meaning something that is the furthest back we support at 32 units gets mapped to 96 units back (out of ~128 maximum))
        Z_OFFSET: signed(15 downto 0) := to_signed(64 *  256,16);
        -- The distance the viewer is from the screen, used to map coordinates to the screen
        -- Calculation time, we want the maximum x value (32), at z = 0 to be displayed at 7/8 of the width of the screen by default
        -- 64 * 7/8 = Z' * (32)/(64)
        -- 64 * 7/8 = Z' * 1/2
        -- 56 = Z' * 1/2
        -- 112 = Z'
        Z_PRIME: unsigned(15 downto 0) := to_unsigned(integer(112*real(256)), 16)
        -- Essentially we are rendering stuff in a 64x64x64 unit cube centered at 0,0,0 with negative being towards the viewer and positive being away from the viewer
    );
    port (
        -- Clock/reset
        clock: in std_logic;
        reset: in std_logic;

        -- Input values
        x1in: in signed(15 downto 0);
        y1in: in signed(15 downto 0);
        z1in: in signed(15 downto 0);

        x2in: in signed(15 downto 0);
        y2in: in signed(15 downto 0);
        z2in: in signed(15 downto 0);

        x3in: in signed(15 downto 0);
        y3in: in signed(15 downto 0);
        z3in: in signed(15 downto 0);

        projectionBeginEn: in std_logic;

        -- Output values
        x1out: out signed(15 downto 0);
        y1out: out signed(15 downto 0);
        z1out: out signed(15 downto 0);
        
        x2out: out signed(15 downto 0);
        y2out: out signed(15 downto 0);
        z2out: out signed(15 downto 0);

        x3out: out signed(15 downto 0);
        y3out: out signed(15 downto 0);
        z3out: out signed(15 downto 0);

        projectionDoneMode: out std_logic
    );
end ProjectionCalculator;


architecture Procedural of ProjectionCalculator is

    constant HALF_WIDTH: signed(15 downto 0) := to_signed(64 * 256, 16);
    constant HALF_HEIGHT: signed(15 downto 0) := to_signed(64 * 256, 16);

    -- Sign variables
    signal x1sign: std_logic := '0';
    signal y1sign: std_logic := '0';

    signal x2sign: std_logic := '0';
    signal y2sign: std_logic := '0';

    signal x3sign: std_logic := '0';
    signal y3sign: std_logic := '0';

    -- Division variables, use the full 32 bit range to allow for as much precision as possible
    signal x1dividend: unsigned(31 downto 0) := (others => '0');
    signal y1dividend: unsigned(31 downto 0) := (others => '0');
    signal divisor1: unsigned(15 downto 0) := (others => '0');
    signal x1quotient: unsigned(31 downto 0) := (others => '0');
    signal y1quotient: unsigned(31 downto 0) := (others => '0');

    signal x2dividend: unsigned(31 downto 0) := (others => '0');
    signal y2dividend: unsigned(31 downto 0) := (others => '0');
    signal divisor2: unsigned(15 downto 0) := (others => '0');
    signal x2quotient: unsigned(31 downto 0) := (others => '0');
    signal y2quotient: unsigned(31 downto 0) := (others => '0');

    signal x3dividend: unsigned(31 downto 0) := (others => '0');
    signal y3dividend: unsigned(31 downto 0) := (others => '0');
    signal divisor3: unsigned(15 downto 0) := (others => '0');
    signal x3quotient: unsigned(31 downto 0) := (others => '0');
    signal y3quotient: unsigned(31 downto 0) := (others => '0');

    -- Division control signals
    signal divideBeginEn: std_logic;
    signal divideDoneMode: std_logic := '1';

    signal outputEn: std_logic;
begin
    PROJECTION_CONTROLLER: process(clock,reset)
        type projection_state_t is (
            Done,
            BeginningDivision,
            WaitingForDivider
        );
        
        variable state: projection_state_t := Done;

        variable z1offset: signed(15 downto 0);
        variable z2offset: signed(15 downto 0);
        variable z3offset: signed(15 downto 0);
    begin
        if reset then
            state := Done;
        elsif rising_edge(clock) then
            projectionDoneMode <= '0';
            x1dividend <= (others => '0');
            x2dividend <= (others => '0');
            x3dividend <= (others => '0');
    
            y1dividend <= (others => '0');
            y2dividend <= (others => '0');
            y3dividend <= (others => '0');
    
            z1offset := z1in + Z_OFFSET;
            z2offset := z2in + Z_OFFSET;
            z3offset := z3in + Z_OFFSET;
    
            divideBeginEn <= '0';
            case state is
                when Done =>
                    projectionDoneMode <= '1';
                    if projectionBeginEn then
                        -- These values flow through
                        z1out <= z1offset;
                        z2out <= z2offset;
                        z3out <= z3offset;

                        x1sign <= z1offset(15) xor x1in(15);
                        y1sign <= z1offset(15) xor y1in(15);

                        x2sign <= z2offset(15) xor x2in(15);
                        y2sign <= z2offset(15) xor y2in(15);

                        x3sign <= z3offset(15) xor x3in(15);
                        y3sign <= z3offset(15) xor y3in(15);

                        x1dividend <= Z_PRIME * unsigned(abs(x1in));
                        y1dividend <= Z_PRIME * unsigned(abs(y1in));       
                        divisor1 <= unsigned(abs(z1offset));
                        
                        x2dividend <= Z_PRIME * unsigned(abs(x2in));
                        y2dividend <= Z_PRIME * unsigned(abs(y2in));
                        divisor2 <= unsigned(abs(z2offset));
                        
                        x3dividend <= Z_PRIME * unsigned(abs(x3in));
                        y3dividend <= Z_PRIME * unsigned(abs(y3in));
                        divisor3 <= unsigned(abs(z3offset));

                        divideBeginEn <= '1';
                        projectionDoneMode <= '0';
                        state := BeginningDivision;
                    end if;
                when BeginningDivision =>
                    state := WaitingForDivider;
                when WaitingForDivider =>
                    if divideDoneMode then
                        state := Done;
                    end if;
            end case;
        end if;
    end process;

    PROJECTION_DIVIDER: process(clock, reset)
        variable shift: integer range 0 to 31;
        variable x1remainder: unsigned(31 downto 0);
        variable y1remainder: unsigned(31 downto 0);
        variable x2remainder: unsigned(31 downto 0);
        variable y2remainder: unsigned(31 downto 0);
        variable x3remainder: unsigned(31 downto 0);
        variable y3remainder: unsigned(31 downto 0);

        variable remainder_portion: unsigned(16 downto 0);
        variable subtraction_result: unsigned(16 downto 0);
        variable quotient_bit: std_logic;

        variable shift_outside: boolean;
        variable inverse_shift: integer range 0 to 31;
    begin
        if reset then
            divideDoneMode <= '1';
        elsif rising_edge(clock) then
            remainder_portion := (others => '0');
            subtraction_result := (others => '0');
            quotient_bit := '0';
            shift_outside := shift+16 > 31;
            inverse_shift := 31 - shift;
            if divideDoneMode and divideBeginEn then
                x1remainder := x1dividend;
                y1remainder := y1dividend;
                x2remainder := x2dividend;
                y2remainder := y2dividend;
                x3remainder := x3dividend;
                y3remainder := y3dividend;
                shift := 31;
                divideDoneMode <= '0';
            elsif not divideDoneMode then
                -- X1 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := x1remainder(31 downto shift);
                else
                    remainder_portion := x1remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor1;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        x1remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        x1remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                x1quotient(shift) <= quotient_bit;

                -- Y1 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := y1remainder(31 downto shift);
                else
                    remainder_portion := y1remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor1;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        y1remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        y1remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                y1quotient(shift) <= quotient_bit;

                -- X2 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := x2remainder(31 downto shift);
                else
                    remainder_portion := x2remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor2;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        x2remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        x2remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                x2quotient(shift) <= quotient_bit;

                -- Y2 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := y2remainder(31 downto shift);
                else
                    remainder_portion := y2remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor2;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        y2remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        y2remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                y2quotient(shift) <= quotient_bit;
                
                -- X3 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := x3remainder(31 downto shift);
                else
                    remainder_portion := x3remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor3;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        x3remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        x3remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                x3quotient(shift) <= quotient_bit;

                -- Y3 division --
                if shift_outside then
                    remainder_portion(inverse_shift downto 0) := y3remainder(31 downto shift);
                else
                    remainder_portion := y3remainder(shift+16 downto shift);
                end if;
                subtraction_result := remainder_portion - divisor3;
                quotient_bit := not subtraction_result(16);
                if quotient_bit then
                    if shift_outside then
                        y3remainder(31 downto shift) := subtraction_result(inverse_shift downto 0);
                    else
                        y3remainder(shift+16 downto shift) := subtraction_result;
                    end if;
                end if;
                y3quotient(shift) <= quotient_bit;

                -- Shift logic --
                if shift = 0 then
                    outputEn <= '1';
                    divideDoneMode <= '1';
                else
                    shift := shift - 1;
                end if;
            end if;
        end if;
    end process;

    OUTPUT_SIGNALS: process(clock)
    begin
        if rising_edge(clock) then
            if outputEn then
                if x1sign then
                    x1out <= HALF_WIDTH - signed(x1quotient(15 downto 0));
                else
                    x1out <= HALF_WIDTH + signed(x1quotient(15 downto 0));
                end if;
                if y1sign then
                    y1out <= HALF_HEIGHT + signed(y1quotient(15 downto 0));
                else
                    y1out <= HALF_HEIGHT - signed(y1quotient(15 downto 0));
                end if;
                if x2sign then
                    x2out <= HALF_WIDTH - signed(x2quotient(15 downto 0));
                else
                    x2out <= HALF_WIDTH + signed(x2quotient(15 downto 0));
                end if;
                if y2sign then
                    y2out <= HALF_HEIGHT + signed(y2quotient(15 downto 0));
                else
                    y2out <= HALF_HEIGHT - signed(y2quotient(15 downto 0));
                end if;
                if x3sign then
                    x3out <= HALF_WIDTH - signed(x3quotient(15 downto 0));
                else
                    x3out <= HALF_WIDTH + signed(x3quotient(15 downto 0));
                end if;
                if y3sign then
                    y3out <= HALF_HEIGHT + signed(y3quotient(15 downto 0));
                else
                    y3out <= HALF_HEIGHT - signed(y3quotient(15 downto 0));
                end if;
            end if;
        end if;
    end process;
end Procedural;