library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package basys3d is


    type PixelEntry is record
        address: std_logic_vector(13 downto 0);
        z: signed(15 downto 0);
        color: std_logic_vector(4 downto 0);
    end record PixelEntry;
    
    component VgaDriver is
        Port(
            clock: in std_logic;
            reset: in std_logic;
    
    
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
    
            pixelInfo: out PixelEntry;
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
    
            pixelInfo: out PixelEntry;
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
    
            pixelInfo: out PixelEntry;
            plotEn: out std_logic;
            pipelineEmpty: out std_logic;
            readyMode: out std_logic
        );
    end component;

    -- Let's use 3 byte entries
    type FramebufferEntry is record
        depth   : signed(15 downto 0);

        color   : std_logic_vector(4 downto 0);
    end record FramebufferEntry;


    type VgaScale is (Normal, Double, Triple);

end basys3d;

package body basys3d is

end basys3d;