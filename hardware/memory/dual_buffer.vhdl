library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_rendering.all;
use work.basys3d_arithmetic.all;

-- Has 2 color buffers, and 1 z-buffer, this should be all that is needed

entity DualBuffer is
    port(
        clock: in std_logic;

        currentWriteBuffer: in std_logic;

        vgaAddress: in std_logic_vector(13 downto 0);
        outVga: out Color;

        readAddress: in std_logic_vector(13 downto 0);
        readData: out signed(15 downto 0);

        writeAddress: in std_logic_vector(13 downto 0);

        writeEn: in std_logic;
        writeData: in FramebufferEntry
    );
end DualBuffer;

architecture Procedural of DualBuffer is

    signal buffer1ReadAddress: std_logic_vector(13 downto 0);

    signal buffer1ReadData: Color;

    signal buffer1WriteAddress: std_logic_vector(13 downto 0);

    signal buffer1WriteEn: std_logic;

    signal buffer2ReadAddress: std_logic_vector(13 downto 0);

    signal buffer2ReadData: Color;

    signal buffer2WriteAddress: std_logic_vector(13 downto 0);

    signal buffer2WriteEn: std_logic;

    signal zReadData: signed(15 downto 0);
begin
    BUFFER_SELECT: process(all)
    begin
        if currentWriteBuffer = '0' then
            buffer1ReadAddress <= (others => '0');
            readData <= zReadData;
            buffer2ReadAddress <= vgaAddress;
            outVga <= buffer2ReadData;
            buffer1WriteAddress <= writeAddress;
            buffer1WriteEn <= writeEn;
            buffer2WriteAddress <= (others => '0');
            buffer2WriteEn <= '0';
        else
            buffer2ReadAddress <= (others => '0');
            readData <= zReadData;
            buffer1ReadAddress <= vgaAddress;
            outVga <= buffer1ReadData;
            buffer2WriteAddress <= writeAddress;
            buffer2WriteEn <= writeEn;
            buffer1WriteAddress <= (others => '0');
            buffer1WriteEn <= '0';
        end if;
    end process;
    
    Z_BUFFER: ZBuffer
    port map (
      clock        => clock,
      readAddress  => readAddress,
      readData     => zReadData,
      writeAddress => writeAddress,
      writeEnable  => writeEn,
      writeData    => writeData.depth
    );
    
    BUFFER_1: Framebuffer port map (
        clock => clock,
        readAddress => buffer1ReadAddress,
        readData => buffer1ReadData,
        writeAddress => buffer1WriteAddress,
        writeEnable => buffer1WriteEn,
        writeData => writeData.color
    );
    
    BUFFER_2: Framebuffer port map (
        clock => clock,
        readAddress => buffer2ReadAddress,
        readData => buffer2ReadData,
        writeAddress => buffer2WriteAddress,
        writeEnable => buffer2WriteEn,
        writeData => writeData.color
    );
end Procedural;