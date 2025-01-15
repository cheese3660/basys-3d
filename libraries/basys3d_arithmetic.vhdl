library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package basys3d_arithmetic is
    type divider_array_t is array(natural range <>) of signed;

    type Color is record
        R: unsigned(4 downto 0);
        G: unsigned(4 downto 0);
        B: unsigned(4 downto 0);
    end record;

    -- Should be enough to store normal vectors
    type Vector10 is record
        X: signed(9 downto 0);
        Y: signed(9 downto 0);
        Z: signed(9 downto 0);
    end record;

    type Vector16 is record
        X: signed(15 downto 0);
        Y: signed(15 downto 0);
        Z: signed(15 downto 0);
    end record;

    type Vector32 is record
        X: signed(31 downto 0);
        Y: signed(31 downto 0);
        Z: signed(31 downto 0);
    end record;

    type Matrix16 is record
        Row1: Vector16;
        Row2: Vector16;
        Row3: Vector16;
    end record;

    -- This calculates the dot product of 2 numbers (used for calculating the luminance values of a triangle in lighting calculations)
    function DotProduct16(
        a: in Vector16;
        b: in Vector16
    ) return signed;

    function MatMul16(
        m: in Matrix16;
        v: in Vector16
    ) return Vector32;

    function ToVector16(
        v: in Vector32
    ) return Vector16;

    function ToVector16(
        v: in Vector10
    ) return Vector16;

    function CreateVector16(
        x: in integer;
        y: in integer;
        z: in integer
    ) return Vector16;

    function CreateVector10(
        x: in integer;
        y: in integer;
        z: in integer
    ) return Vector10;

    function CreateColor(
        r: in integer;
        g: in integer;
        b: in integer
    ) return Color;

    type TrigCalcType is (
        Sine,
        Cosine
    );

    component TrigCalculator is
        port(
            clock: in std_logic;
            reset: in std_logic;
            
            -- The angle being operated on
            theta: in signed(15 downto 0);
    
            -- The operation to compute
            operation: in TrigCalcType;
    
            beginCalculation: in std_logic;
    
            result: out signed(15 downto 0);
            operationDoneMode: out std_logic
        );
    end component;
end basys3d_arithmetic;

package body basys3d_arithmetic is
    function DotProduct16(
        a: in Vector16;
        b: in Vector16
    ) return signed is
    begin
        return (a.X * b.X) + (a.Y * b.Y) + (a.Z * b.Z);
    end function;

    function MatMul16(
        m: in Matrix16;
        v: in Vector16
    ) return Vector32 is
    begin
        return (
            X => DotProduct16(v,m.Row1),
            Y => DotProduct16(v,m.Row2),
            Z => DotProduct16(v,m.Row3)
        );
    end function;

    function ToVector16(
        v: in Vector32
    ) return Vector16 is
    begin
        return (
            X => v.X(23 downto 8),
            Y => v.Y(23 downto 8),
            Z => v.Z(23 downto 8) 
        );
    end function;

    function ToVector16(
        v: in Vector10
    ) return Vector16 is
    begin
        return (
            X => resize(v.X, 16),
            Y => resize(v.Y, 16),
            Z => resize(v.Z, 16)
        );
    end function;

    function CreateVector16(
        x: in integer;
        y: in integer;
        z: in integer
    ) return Vector16 is
    begin
        return (
            X => to_signed(x, 16),
            Y => to_signed(y, 16),
            Z => to_signed(z, 16)
        );
    end function;

    function CreateVector10(
        x: in integer;
        y: in integer;
        z: in integer
    ) return Vector10 is
    begin
        return (
            X => to_signed(x, 10),
            Y => to_signed(y, 10),
            Z => to_signed(z, 10)
        );
    end function;

    
    function CreateColor(
        r: in integer;
        g: in integer;
        b: in integer
    ) return Color is
    begin
        return (
            R => to_unsigned(r,5),
            G => to_unsigned(g,5),
            B => to_unsigned(b,5)
        );
    end function;
end basys3d_arithmetic;