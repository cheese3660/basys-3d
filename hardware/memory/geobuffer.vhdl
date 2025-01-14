library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d_geometry.all;

entity GeoBuffer is
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
end GeoBuffer;

architecture Procedural of GeoBuffer is
    type GeoBufferType is array (0 to MAX_TRIANGLE_COUNT-1) of GeoTriangle;

    signal gb: GeoBufferType;
begin

    WRITE_DATA: process(clock)
    begin
        if rising_edge(clock) then
            if writeEnable then
                gb(writeAddress) <= writeData;
            end if;
            readData <= gb(readAddress);
        end if;
    end process;
end Procedural;