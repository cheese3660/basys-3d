library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.basys3d.all;
use work.basys3d_arithmetic.all;

package basys3d_rendering is
    component TrianglePlotter is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            x1: in signed(15 downto 0);
            y1: in signed(7 downto 0);
            z1: in signed(15 downto 0);
    
            x2: in signed(15 downto 0);
            y2: in signed(7 downto 0);
            z2: in signed(15 downto 0);
    
            x3: in signed(15 downto 0);
            y3: in signed(7 downto 0);
            z3: in signed(15 downto 0);
    
            color: in std_logic_vector(4 downto 0);
    
            plotTriangleEn: in std_logic;
    
            readyMode: out std_logic;
            pipelineEmpty: out std_logic;
    
            writeAddress: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readAddress: out std_logic_vector(13 downto 0);
            readData: in FramebufferEntry;
            writeEn: out std_logic
        );
    end component;

    component SevenSegmentDriver is
        port(
            reset: in std_logic;
            clock: in std_logic;
    
            digit3: in std_logic_vector(3 downto 0);    --leftmost digit
            digit2: in std_logic_vector(3 downto 0);    --2nd from left digit
            digit1: in std_logic_vector(3 downto 0);    --3rd from left digit
            digit0: in std_logic_vector(3 downto 0);    --rightmost digit
    
            blank3: in std_logic;    --leftmost digit
            blank2: in std_logic;    --2nd from left digit
            blank1: in std_logic;    --3rd from left digit
            blank0: in std_logic;    --rightmost digit
    
            sevenSegs: out std_logic_vector(6 downto 0);    --MSB=g, LSB=a
            anodes:    out std_logic_vector(3 downto 0)    --MSB=leftmost digit
        );
    end component;

    component FrameRenderer is
        port (
            clock: in std_logic;
            reset: in std_logic;
    
            -- VGA Control Signals
            readingFromMemory: in std_logic;
            endFrameEn: in std_logic;
    
            -- Framebuffer control signals
            bufferSelect: out std_logic;
    
            readAddress: out std_logic_vector(13 downto 0);
            readData: in FramebufferEntry;
    
            writeAddress: out std_logic_vector(13 downto 0);
            writeEn: out std_logic;
            writeData: out FramebufferEntry;
    
            -- FPS Display
            fpsOne: out integer range 0 to 9;
            fpsTwo: out integer range 0 to 9;
            fpsThree: out integer range 0 to 9;
            fpsFour: out integer range 0 to 9
        );
    end component;


    component LowerHalfPipeline is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            x1: in signed(15 downto 0);
            y1: in signed(7 downto 0);
            z1: in signed(15 downto 0);
    
            x2: in signed(15 downto 0);
            y2: in signed(7 downto 0);
            z2: in signed(15 downto 0);
        
            x3: in signed(15 downto 0);
            y3: in signed(7 downto 0);
            z3: in signed(15 downto 0);
    
            color: in std_logic_vector(4 downto 0);
    
            hasValue: in std_logic;
        
            readyMode: out std_logic;
            pipelineEmpty: out std_logic;
    
            onReadCycle: in std_logic;
            onWriteCycle: in std_logic;
    
            address: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readData: in FramebufferEntry;
            plotEn: out std_logic
        );
    end component;

    component UpperHalfPipeline is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            x1: in signed(15 downto 0);
            y1: in signed(7 downto 0);
            z1: in signed(15 downto 0);
    
            x2: in signed(15 downto 0);
            y2: in signed(7 downto 0);
            z2: in signed(15 downto 0);
        
            x3: in signed(15 downto 0);
            y3: in signed(7 downto 0);
            z3: in signed(15 downto 0);
    
            color: in std_logic_vector(4 downto 0);
    
            hasValue: in std_logic;
        
            readyMode: out std_logic;
            pipelineEmpty: out std_logic;
    
            onReadCycle: in std_logic;
            onWriteCycle: in std_logic;
    
            address: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readData: in FramebufferEntry;
            plotEn: out std_logic
        );
    end component;

    component Framebuffer is
        port(
            clock: in std_logic;
    
            readAddress: in std_logic_vector(13 downto 0);
            readData: out FramebufferEntry;
            writeAddress: in std_logic_vector(13 downto 0);
            writeEnable: in std_logic;
            writeData: in FramebufferEntry
        );
    end component;

    component DualBuffer is
        port(
            clock: in std_logic;
    
            currentWriteBuffer: in std_logic;
    
            vgaAddress: in std_logic_vector(13 downto 0);
            outVga: out FramebufferEntry;
    
            readAddress: in std_logic_vector(13 downto 0);
            readData: out FramebufferEntry;
    
            writeAddress: in std_logic_vector(13 downto 0);
    
            writeEn: in std_logic;
            writeData: in FramebufferEntry
        );
    end component;

    component VgaDriver is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            -- This is the address that the VGA circuitry is reading from
            addr: out std_logic_vector(13 downto 0);
            fbe: in FramebufferEntry;
    
            -- This is the current scale of the VGA display
            scale: in VgaScale;
    
            -- Is the VGA display currently reading from memory (don't switch framebuffers while this is happening)
            readingFromMemory: out std_logic;
    
            -- Sent at the end of a frame to denote that a frame end has happened (will be used to count FPS)
            endFrameEn: out std_logic;
    
            red: out std_logic_vector(3 downto 0);
            green: out std_logic_vector(3 downto 0);
            blue: out std_logic_vector(3 downto 0);
    
            hSync: out std_logic;
            vSync: out std_logic
        );
    end component;

    component ScanlinePipeline is
        port(
            clock: in std_logic;
            reset: in std_logic;    
    
            scanlineY: in unsigned(6 downto 0);
            scanlineX0: in signed(7 downto 0);
            scanlineX1: in signed(7 downto 0);
            scanlineZ0: in signed(15 downto 0);
            scanlineZ1: in signed(15 downto 0);
    
            scanlineColor: in std_logic_vector(4 downto 0);
    
            scanlinePlotEn: in std_logic;
    
            onReadCycle: in std_logic;
            onWriteCycle: in std_logic;
    
            address: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readData: in FramebufferEntry;
            plotEn: out std_logic;
    
            pipelineEmpty: out std_logic;
            canAcceptScanline: out std_logic
        );
    end component;


    component UpperHalfPlotter is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            xSlope1: in signed(15 downto 0);
            zSlope1: in signed(15 downto 0);
            xSlope2: in signed(15 downto 0);
            zSlope2: in signed(15 downto 0);
            
            minX: in signed(7 downto 0);
            maxX: in signed(7 downto 0);
    
            startX: in signed(15 downto 0);
            startZ: in signed(15 downto 0);
    
            startY: in signed(7 downto 0);
            endY: in signed(7 downto 0);
    
            trigColor: in std_logic_vector(4 downto 0);
    
            beginPlotEn: in std_logic;
    
            onReadCycle: in std_logic;
            onWriteCycle: in std_logic;
    
            address: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readData: in FramebufferEntry;
            plotEn: out std_logic;
            pipelineEmpty: out std_logic;
            readyMode: out std_logic
        );
    end component;

    component LowerHalfPlotter is

        Port(
            clock: in std_logic;
            reset: in std_logic;
    
            xSlope1: in signed(15 downto 0);
            zSlope1: in signed(15 downto 0);
            xSlope2: in signed(15 downto 0);
            zSlope2: in signed(15 downto 0);
            
            minX: in signed(7 downto 0);
            maxX: in signed(7 downto 0);
    
            startX: in signed(15 downto 0);
            startZ: in signed(15 downto 0);
    
            startY: in signed(7 downto 0);
            endY: in signed(7 downto 0);
    
            trigColor: in std_logic_vector(4 downto 0);
    
            beginPlotEn: in std_logic;
    
            onReadCycle: in std_logic;
            onWriteCycle: in std_logic;
    
            address: out std_logic_vector(13 downto 0);
            writeData: out FramebufferEntry;
            readData: in FramebufferEntry;
            plotEn: out std_logic;
            pipelineEmpty: out std_logic;
            readyMode: out std_logic
        );
    end component;
end basys3d_rendering;