-- This implements a 128x128 frame/depth buffer for the FPGA
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;


-- This system will be double buffered to make a lot of the logic for drawing simpler

-- There will be logic to make it so switches cannot happen while a frame is being transmitted over VGA
entity Framebuffer is
    port(
        clock: in std_logic;

        readAddress: in std_logic_vector(13 downto 0);
        readData: out Color;
        writeAddress: in std_logic_vector(13 downto 0);
        writeEnable: in std_logic;
        writeData: in Color
    );
end Framebuffer;

architecture Procedural of Framebuffer is
    type frameBufferType is array (0 to 16383) of Color;

    signal fb: frameBufferType;

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