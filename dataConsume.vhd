----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2020 11:12:40
-- Design Name: 
-- Module Name: dataProcessor - Behavioral
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dataConsume is
    port (
        clk : in std_logic;
        reset : in std_logic; -- synchronous reset
        start : in std_logic;        
        numWords_bcd : in BCD_ARRAY_TYPE(2 downto 0);
        ctrlIn : in std_logic;
        ctrlOut : out std_logic;
        data : in std_logic_vector(7 downto 0);
        dataReady : out std_logic;
        byte : out std_logic_vector(7 downto 0);
        seqDone : out std_logic;
        maxIndex : out BCD_ARRAY_TYPE(2 downto 0);        
        dataResults : out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) 
    );
end dataConsume;

architecture Behavioral of dataConsume is

begin


end Behavioral;
