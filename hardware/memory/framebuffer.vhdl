-- This implements a 128x128 frame/depth buffer for the FPGA
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;


-- This system will be double buffered to make a lot of the logic for drawing simpler

-- There will be logic to make it so switches cannot happen while a frame is being transmitted over VGA
entity Framebuffer is
    port(
        clock: in std_logic;

        address1: in std_logic_vector(13 downto 0);
        outEntry1: out FramebufferEntry;

        address2: in std_logic_vector(13 downto 0);
        outEntry2: out FramebufferEntry;

        write1: in std_logic;
        inEntry1: in FramebufferEntry;
        write2: in std_logic;
        inEntry2: in FramebufferEntry
    );
end Framebuffer;

architecture Procedural of Framebuffer is
    type zBufferType is array (0 to 16383) of signed(15 downto 0);
    type colorBufferType is array (0 to 16383) of std_logic_vector(4 downto 0);

    signal zBuffer: zBufferType;
    signal colorBuffer: colorBufferType;

    signal address1Int: integer range 0 to 16383;
    signal address2Int: integer range 0 to 16383;
begin
    address1Int <= to_integer(unsigned(address1));
    address2Int <= to_integer(unsigned(address2));

    outEntry1 <= (
        depth => zBuffer(address1Int),
        color => colorBuffer(address1Int)
    );

    outEntry2 <= (
        depth => zBuffer(address2Int),
        color => colorBuffer(address2Int)
    );

    WRITE_ONE: process(clock)
    begin
        if rising_edge(clock) then
            if write1 then
                zBuffer(address1Int) <= inEntry1.depth;
                colorBuffer(writeAddress1Int) <= inEntry1.color;
            end if;
        end if;
    end process;

    WRITE_TWO: process(clock)
    begin
        if rising_edge(clock) then
            if write2 then
                zBuffer(address2Int) <= inEntry2.depth;
                colorBuffer(address2Int) <= inEntry2.color;
            end if;
        end if;
    end process;
end Procedural;