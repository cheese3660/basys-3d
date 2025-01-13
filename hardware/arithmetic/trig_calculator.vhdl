-- Used to calculate fixed point trig calculations with an input angle between -128 and 127 + 255/256

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_arithmetic.all;

entity TrigCalculator is
    port(
        clock: in std_logic;
        reset: in std_logic;
        
        -- The angle being operated on
        theta: in signed(15 downto 0);

        -- The operation to compute
        operation: in TrigCalcType;

        beginCalculation: in std_logic;

        result: out signed(15 downto 0);
        operationDoneMode: out std_logic
    );
end TrigCalculator;

architecture Procedural of TrigCalculator is


    -- Trig calculation constants
    type trig_table_t is array(0 to 255) of signed(15 downto 0);

    -- Trig values for the first quarter period of a sine wave
    constant trig_table: trig_table_t := (
        to_signed(0,16),
        to_signed(1,16),
        to_signed(3,16),
        to_signed(4,16),
        to_signed(6,16),
        to_signed(7,16),
        to_signed(9,16),
        to_signed(10,16),
        to_signed(12,16),
        to_signed(14,16),
        to_signed(15,16),
        to_signed(17,16),
        to_signed(18,16),
        to_signed(20,16),
        to_signed(21,16),
        to_signed(23,16),
        to_signed(25,16),
        to_signed(26,16),
        to_signed(28,16),
        to_signed(29,16),
        to_signed(31,16),
        to_signed(32,16),
        to_signed(34,16),
        to_signed(36,16),
        to_signed(37,16),
        to_signed(39,16),
        to_signed(40,16),
        to_signed(42,16),
        to_signed(43,16),
        to_signed(45,16),
        to_signed(46,16),
        to_signed(48,16),
        to_signed(49,16),
        to_signed(51,16),
        to_signed(53,16),
        to_signed(54,16),
        to_signed(56,16),
        to_signed(57,16),
        to_signed(59,16),
        to_signed(60,16),
        to_signed(62,16),
        to_signed(63,16),
        to_signed(65,16),
        to_signed(66,16),
        to_signed(68,16),
        to_signed(69,16),
        to_signed(71,16),
        to_signed(72,16),
        to_signed(74,16),
        to_signed(75,16),
        to_signed(77,16),
        to_signed(78,16),
        to_signed(80,16),
        to_signed(81,16),
        to_signed(83,16),
        to_signed(84,16),
        to_signed(86,16),
        to_signed(87,16),
        to_signed(89,16),
        to_signed(90,16),
        to_signed(92,16),
        to_signed(93,16),
        to_signed(95,16),
        to_signed(96,16),
        to_signed(97,16),
        to_signed(99,16),
        to_signed(100,16),
        to_signed(102,16),
        to_signed(103,16),
        to_signed(105,16),
        to_signed(106,16),
        to_signed(108,16),
        to_signed(109,16),
        to_signed(110,16),
        to_signed(112,16),
        to_signed(113,16),
        to_signed(115,16),
        to_signed(116,16),
        to_signed(117,16),
        to_signed(119,16),
        to_signed(120,16),
        to_signed(122,16),
        to_signed(123,16),
        to_signed(124,16),
        to_signed(126,16),
        to_signed(127,16),
        to_signed(128,16),
        to_signed(130,16),
        to_signed(131,16),
        to_signed(132,16),
        to_signed(134,16),
        to_signed(135,16),
        to_signed(136,16),
        to_signed(138,16),
        to_signed(139,16),
        to_signed(140,16),
        to_signed(142,16),
        to_signed(143,16),
        to_signed(144,16),
        to_signed(146,16),
        to_signed(147,16),
        to_signed(148,16),
        to_signed(149,16),
        to_signed(151,16),
        to_signed(152,16),
        to_signed(153,16),
        to_signed(155,16),
        to_signed(156,16),
        to_signed(157,16),
        to_signed(158,16),
        to_signed(159,16),
        to_signed(161,16),
        to_signed(162,16),
        to_signed(163,16),
        to_signed(164,16),
        to_signed(166,16),
        to_signed(167,16),
        to_signed(168,16),
        to_signed(169,16),
        to_signed(170,16),
        to_signed(171,16),
        to_signed(173,16),
        to_signed(174,16),
        to_signed(175,16),
        to_signed(176,16),
        to_signed(177,16),
        to_signed(178,16),
        to_signed(179,16),
        to_signed(181,16),
        to_signed(182,16),
        to_signed(183,16),
        to_signed(184,16),
        to_signed(185,16),
        to_signed(186,16),
        to_signed(187,16),
        to_signed(188,16),
        to_signed(189,16),
        to_signed(190,16),
        to_signed(191,16),
        to_signed(192,16),
        to_signed(193,16),
        to_signed(194,16),
        to_signed(195,16),
        to_signed(196,16),
        to_signed(197,16),
        to_signed(198,16),
        to_signed(199,16),
        to_signed(200,16),
        to_signed(201,16),
        to_signed(202,16),
        to_signed(203,16),
        to_signed(204,16),
        to_signed(205,16),
        to_signed(206,16),
        to_signed(207,16),
        to_signed(208,16),
        to_signed(209,16),
        to_signed(210,16),
        to_signed(211,16),
        to_signed(211,16),
        to_signed(212,16),
        to_signed(213,16),
        to_signed(214,16),
        to_signed(215,16),
        to_signed(216,16),
        to_signed(217,16),
        to_signed(217,16),
        to_signed(218,16),
        to_signed(219,16),
        to_signed(220,16),
        to_signed(221,16),
        to_signed(221,16),
        to_signed(222,16),
        to_signed(223,16),
        to_signed(224,16),
        to_signed(225,16),
        to_signed(225,16),
        to_signed(226,16),
        to_signed(227,16),
        to_signed(227,16),
        to_signed(228,16),
        to_signed(229,16),
        to_signed(230,16),
        to_signed(230,16),
        to_signed(231,16),
        to_signed(232,16),
        to_signed(232,16),
        to_signed(233,16),
        to_signed(234,16),
        to_signed(234,16),
        to_signed(235,16),
        to_signed(235,16),
        to_signed(236,16),
        to_signed(237,16),
        to_signed(237,16),
        to_signed(238,16),
        to_signed(238,16),
        to_signed(239,16),
        to_signed(239,16),
        to_signed(240,16),
        to_signed(241,16),
        to_signed(241,16),
        to_signed(242,16),
        to_signed(242,16),
        to_signed(243,16),
        to_signed(243,16),
        to_signed(244,16),
        to_signed(244,16),
        to_signed(244,16),
        to_signed(245,16),
        to_signed(245,16),
        to_signed(246,16),
        to_signed(246,16),
        to_signed(247,16),
        to_signed(247,16),
        to_signed(247,16),
        to_signed(248,16),
        to_signed(248,16),
        to_signed(249,16),
        to_signed(249,16),
        to_signed(249,16),
        to_signed(250,16),
        to_signed(250,16),
        to_signed(250,16),
        to_signed(251,16),
        to_signed(251,16),
        to_signed(251,16),
        to_signed(251,16),
        to_signed(252,16),
        to_signed(252,16),
        to_signed(252,16),
        to_signed(252,16),
        to_signed(253,16),
        to_signed(253,16),
        to_signed(253,16),
        to_signed(253,16),
        to_signed(254,16),
        to_signed(254,16),
        to_signed(254,16),
        to_signed(254,16),
        to_signed(254,16),
        to_signed(254,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        to_signed(255,16),
        -- Specifically making it so exact angles get 1.00 rather than 0.ff
        to_signed(256,16)
    );
begin

    CALCULATE: process(clock, reset)

        type CalculationState is (
            Waiting,
            FindingIndex,
            Reading,
            AddingSign
        );

        type Direction is (
            Forwards,
            Backwards
        );

        type ResultSign is (
            Pos,
            Neg
        );

        variable dir: Direction;
        variable sgn: ResultSign;
        variable idx: unsigned(7 downto 0);
        variable res: signed(15 downto 0);
        variable state: CalculationState := Waiting;
        variable unsignedTheta: unsigned(15 downto 0);
    begin
        if reset then
            state := Waiting;
        elsif rising_edge(clock) then
            operationDoneMode <= '0';
            unsignedTheta := (others => '0');
            case state is
                when Waiting =>
                    operationDoneMode <= '1';
                    if beginCalculation then
                        operationDoneMode <= '0';
                        unsignedTheta := unsigned(theta);
                        idx := unsignedTheta(13 downto 6);
                        case operation is
                            when Sine =>
                                case unsignedTheta(15 downto 14) is
                                    when "00" =>
                                        dir := Forwards;
                                        sgn := Pos;
                                    when "01" =>
                                        dir := Backwards;
                                        sgn := Pos;
                                    when "10" =>
                                        dir := Forwards;
                                        sgn := Neg;
                                    when others =>
                                        dir := Backwards;
                                        sgn := Neg;
                                end case;
                            when Cosine =>
                                case unsignedTheta(15 downto 14) is
                                    when "00" =>
                                        dir := Backwards;
                                        sgn := Pos;
                                    when "01" =>
                                        dir := Forwards;
                                        sgn := Neg;
                                    when "10" =>
                                        dir := Backwards;
                                        sgn := Neg;
                                    when others =>
                                        dir := Forwards;
                                        sgn := Pos;
                                end case;
                        end case;
                        state := FindingIndex;
                    end if;
                when FindingIndex =>
                    if dir = Backwards then
                        idx := 255 - idx;
                    end if;
                    state := Reading;
                when Reading =>
                    res := trig_table(to_integer(idx));
                    state := AddingSign;
                when AddingSign =>
                    case sgn is
                        when Pos =>
                            result <= res;
                        when Neg =>
                            result <= -res;
                    end case;
                    state := Waiting;
            end case;
        end if;
    end process;
end Procedural;