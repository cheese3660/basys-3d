library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package basys3d is
    type PixelEntry is record
        address: std_logic_vector(13 downto 0);
        z: signed(15 downto 0);
        color: std_logic_vector(4 downto 0);
    end record PixelEntry;

    -- Let's use 3 byte entries
    type FramebufferEntry is record
        depth   : signed(15 downto 0);

        color   : std_logic_vector(4 downto 0);
    end record FramebufferEntry;

    type VgaScale is (SingleRes, DoubleRes, TripleRes);


    procedure ReportPixel(pixel: in PixelEntry);
end basys3d;

package body basys3d is

    procedure ReportPixel(pixel: in PixelEntry) is
    begin
        report "PIX:X=" & to_string(to_integer(unsigned(pixel.address(6 downto 0)))) & "Y=" & to_string(to_integer(unsigned(pixel.address(13 downto 7)))) & "Z="  & to_string(to_integer(pixel.z)) & "C=" & to_string(to_integer(unsigned(pixel.color))) & ";";
    end;
end basys3d;