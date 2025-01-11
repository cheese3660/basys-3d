library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;

-- Makes sure that only the closest pixels get drawn
entity PixelSynchronizer is
    Port(
        inA: in PixelEntry;
        plotAEn: in std_logic;

        inB: in PixelEntry;
        plotBEn: in std_logic;

        addrA: out std_logic_vector(13 downto 0);
        inFbeA: in FramebufferEntry;
        outFbeA: out FramebufferEntry;
        writeAEn: out std_logic;

        addrB: out std_logic_vector(13 downto 0);
        inFbeB: in FramebufferEntry;
        outFbeB: out FramebufferEntry;
        writeBEn: out std_logic
    );
end PixelSynchronizer;

architecture Procedural of PixelSynchronizer is
begin
    addrA <= inA.address;
    outFbeA <= (
        depth => inA.z,
        color => inA.color
    );

    addrB <= inB.address;
    outFbeB <= (
        depth => inB.z,
        color => inB.color
    );

    writeAEn <= plotAEn when inA.z < inFbeA.depth else '0';
    writeBEn <= plotBEn when inB.z < inFbeB.depth else '0';
end Procedural;