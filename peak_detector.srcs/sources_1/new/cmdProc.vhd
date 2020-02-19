----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2020 11:12:40
-- Design Name: 
-- Module Name: cmdProcessor - Behavioral
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

entity cmdProc is
    port (
          clk : in std_logic;
          reset : in std_logic;
          rxnow : in std_logic;     --valid
          rxData : in std_logic_vector (7 downto 0);    --data_rx
          txData : out std_logic_vector (7 downto 0);   --data_tx
          rxdone : out std_logic;   --done
          ovErr : in std_logic; --oe
          framErr : in std_logic;   --fe
          txnow : out std_logic;    --txNow
          txdone : in std_logic;    --txDone
          start : out std_logic;    --start
          numWords_bcd : out BCD_ARRAY_TYPE(2 downto 0);    --numWords
          dataReady : in std_logic; --dataReady
          byte : in std_logic_vector(7 downto 0);   --byte
          maxIndex : in BCD_ARRAY_TYPE(2 downto 0); --maxIndex
          dataResults : in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1); --dataResults
          seqDone : in std_logic    --seqDone
        );
end cmdProc;

architecture Behavioral of cmdProc is
signal srst1, srst0 : std_logic;
signal en1, en0 : std_logic;
signal value1, value0 : std_logic_vector(3 downto 0);

TYPE state_type IS (INIT, FIRST, SECOND);   --three states in the state machine
SIGNAL curState, nextState: state_type;
signal x_reg : std_logic;

begin
-------------------------------------------------------------------
combi_nextState: PROCESS(curState, rxnow)
begin
    case curState is
        when INIT =>
            if x_reg = '1' then
                srst1 <= '1';
                srst0 <= '1';
                en1 <= '0';
                en0 <= '0';
                nextState <= INIT;
            else
                srst0 <= '0';
                en0 <= '1';
                nextState <= FIRST;
            end if;

        when FIRST =>
            if (x_reg = '0') and (value0_reg <= "1111")  then
                nextState <= FIRST;
            elsif ((x_reg = '1') and (value0_reg = "1110")) then
                en0 <= '0';
                en1 <= '1';
                srst0 <= '1';
                srst1 <= '0';
                nextState <= SECOND;
            else
                srst0 <= '1';
                en0 <= '0';
                nextState <= INIT;
            end if;

        when SECOND =>
            if ((x_reg = '1') and (value1_reg /= "1111")) then
                nextState <= SECOND;
            elsif ((x_reg = '0') and (value1_reg < "1111")) then
                en1 <= '0';
                srst1 <= '1';
                en0 <= '1';
                srst1 <= '0';
                nextState <= FIRST;                    
            else
                en1 <= '0';
                srst1 <= '1';
                nextState <= INIT;
            end if;
        when others =>
            srst1 <= '1';
            srst0 <= '1';
            en1 <= '0'; 
            en0 <= '0';
            nextState <= INIT;
    end case;
end process; 
-------------------------------------------------------------------
seq_state: PROCESS (clk, reset)
BEGIN
  IF reset = '0' THEN
    curState <= INIT;
  ELSIF clk'EVENT AND clk='1' THEN
    curState <= nextState;
  END IF;
END PROCESS; -- seq
-------------------------------------------------------------------
registers: PROCESS(clk)
BEGIN
    IF clk'event AND clk='1' THEN
        x_reg <= to_stdulogic(x);
        value0_reg <= value0;
        value1_reg <= value1;
    END IF;
END PROCESS;
-------------------------------------------------------------------
combi_out: PROCESS(curState, x_reg, value1_reg)
BEGIN
y <= '0'; -- assign default value
IF curState = SECOND AND x_reg = '1' AND value1_reg = "1111" THEN
y <= '1';
END IF;
END PROCESS; -- combi_output
-------------------------------------------------------------------

end Behavioral;
