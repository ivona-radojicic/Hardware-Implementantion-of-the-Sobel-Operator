library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package RAM_definitions_PK is
    function clogb2( depth : natural) return integer;
end RAM_definitions_PK;

package body RAM_definitions_PK is
    --Insert the following in the architecture before the begin keyword
    --  The following function calculates the address width based on specified RAM depth
    function clogb2( depth : natural) return integer is
    variable temp    : integer := depth;
    variable ret_val : integer := 0;
    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;
        return ret_val;
    end function;
    
end package body RAM_definitions_PK;