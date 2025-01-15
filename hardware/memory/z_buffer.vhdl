library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;

entity ZBuffer is
    port(
        clock: in std_logic;

        readAddress: in std_logic_vector(13 downto 0);

        readData: out signed(15 downto 0);
        writeAddress: in std_logic_vector(13 downto 0);
        writeEnable: in std_logic;
        writeData: in signed(15 downto 0)
    );
end ZBuffer;

architecture Procedural of ZBuffer is
    type zBufferType is array (0 to 16383) of signed(15 downto 0);

    signal fb: zBufferType;

    signal readAddressInt: integer range 0 to 16383;
    signal writeAddressInt: integer range 0 to 16383;
begin
    readAddressInt <= to_integer(unsigned(readAddress));
    writeAddressInt <= to_integer(unsigned(writeAddress));

    WRITE_DATA: process(clock)
    begin
        if rising_edge(clock) then
            if writeEnable then
                fb(writeAddressInt) <= writeData;
            end if;
            readData <= fb(readAddressInt);
        end if;
    end process;
end Procedural;