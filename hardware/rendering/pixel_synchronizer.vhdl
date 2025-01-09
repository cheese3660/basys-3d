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
        writeBEn: out std_logic;
    );
end PixelSynchronizer;

architecture Procedural of PixelSynchronizer is
    signal stopA: std_logic;
    signal stopB: std_logic;
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

    SYNCHRONIZE: process(inA, inB, inFbeA, inFbeB) is
        variable aMask: boolean;
        variable bMask: boolean;
    begin
        aMask := inA.z < inFbeA.depth;
        bMask := inB.z < inFbeB.depth;
        
        if inA.address = inB.address and plotAEn and plotBEn then
            if inA.z < inB.z then
                bMask := false;
            else
                aMask := false;
            end if;
        end if;

        if aMask then
            writeAEn <= plotAEn;
        else
            writeAEn <= '0';
        end if;

        if bMask then
            writeBEn <= plotBEn;
        else
            writeBEn <= '0';
        end if;
    end process;
end Procedural;