library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.basys3d_arithmetic.all;

package basys3d is

    -- Let's use 3 byte entries
    type FramebufferEntry is record
        depth   : signed(15 downto 0);

        color   : Color;
    end record FramebufferEntry;

    type VgaScale is (SingleRes, DoubleRes, TripleRes);


    procedure ReportPixel(address: in std_logic_vector(13 downto 0); c: in Color);
end basys3d;

package body basys3d is

    procedure ReportPixel(address: in std_logic_vector(13 downto 0); c: in Color) is
    begin
        report "PIX:X=" & to_string(to_integer(unsigned(address(6 downto 0)))) & "Y=" & to_string(to_integer(unsigned(address(13 downto 7)))) & "R=" & to_string(to_integer(unsigned(c.R))) & "G=" & to_string(to_integer(unsigned(c.G)))& "B=" & to_string(to_integer(unsigned(c.B))) & ";";
    end;
end basys3d;