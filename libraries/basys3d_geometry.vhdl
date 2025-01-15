library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_arithmetic.all;

package basys3d_geometry is
    type GeoTriangle is record
        A: Vector16;
        B: Vector16;
        C: Vector16;
        N: Vector10;
        COL: Color;
    end record;

    procedure ReportTrig(trig: in Geotriangle);

    component GeoBuffer is
        generic (
            MAX_TRIANGLE_COUNT: integer range 0 to 65535
        );
        port(
            clock: in std_logic;
    
            readAddress: in integer range 0 to MAX_TRIANGLE_COUNT-1;
            readData: out GeoTriangle;
            writeAddress: in integer range 0 to MAX_TRIANGLE_COUNT-1;
            writeEnable: in std_logic;
            writeData: in GeoTriangle
        );
    end component;
end basys3d_geometry;


package body basys3d_geometry is
    procedure ReportTrig(trig: in Geotriangle) is
    begin
        report "A[" & to_string(to_integer(trig.A.X)) & ", " & to_string(to_integer(trig.A.Y)) & ", " & to_string(to_integer(trig.A.Z)) & "], " &
               "B[" & to_string(to_integer(trig.B.X)) & ", " & to_string(to_integer(trig.B.Y)) & ", " & to_string(to_integer(trig.B.Z)) & "], " &
               "C[" & to_string(to_integer(trig.C.X)) & ", " & to_string(to_integer(trig.C.Y)) & ", " & to_string(to_integer(trig.C.Z)) & "], " &
               "N[" & to_string(to_integer(trig.N.X)) & ", " & to_string(to_integer(trig.N.Y)) & ", " & to_string(to_integer(trig.N.Z)) & "], " &
               "COL[" & to_string(to_integer(trig.COL.R)) & ", " & to_string(to_integer(trig.COL.G)) & ", " & to_string(to_integer(trig.COL.B)) & "];";
    end procedure;
end basys3d_geometry;