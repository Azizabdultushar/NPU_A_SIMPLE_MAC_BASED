----------------------------------------------------------------------------------
-- Company: Bohemian
-- Author: Tusher Aziz
-- 
-- Create Date: 06.09.2026 10:17:35
-- Design Name: 
-- Module Name: simple_mac_npu - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
use IEEE.NUMERIC_STD.ALL;

entity Simple_NPU is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;

        act_in  : in  SIGNED(7 downto 0);   -- INT8 activation
        wgt_in  : in  SIGNED(7 downto 0);   -- INT8 weight

        valid   : in  STD_LOGIC; --kind of control signal to control whether a MAC operation happens or not.
                                --if valid = 1 perform MAC operation if valid = 0; do nothing.
        result  : out SIGNED(31 downto 0)  -- I have act_in is 127 and then weight is 127 so the largest product would be 16129=(127x127)
        --to represent this 16129, I need 15 bits plus a sign bit, so 16 bits
        --After 100 MAC operations 100x16129 = 1612900.
        -- 16 bit signed number can only hold -32768 to 32767
        -- 32 bit accumulator can hold -2,147,483,648 to  +2,147,483,647
        -- now I can accumulate many products safely 1000x16129 = 1612900
        
    );
end Simple_NPU;

architecture Behavioral of Simple_NPU is --achitecture define how the HW works internally

    signal acc : SIGNED(31 downto 0) := (others => '0'); --creating 32 bit register to store accumulator 32 bit results

begin --start actual HW behavior

    process(clk) --sequential logic driven by clock like for FF ,Register, state machines
        variable mult_result : SIGNED(15 downto 0); -- temporary storage for Multiplication result (8x8 bit) so 16 bit is enough
    begin
        if rising_edge(clk) then --only excute once per clock cycle

            if rst = '1' then
                acc <= (others => '0');

            elsif valid = '1' then

                -- INT8 × INT8
                mult_result := act_in * wgt_in;

                -- Accumulate into INT32
                acc <= acc + resize(mult_result, 32);

            end if; --end if rst status changes.
        end if; -- end if clock risign status changes.
    end process; --end sequential hardware description

    result <= acc; -- output result reflects in accumulator.

end Behavioral;
