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
-- synthesis translate_off
use UNISIM.VPKG.ALL;
-- synthesis translate_on

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
signal oe, fe, valid : std_logic;
signal data_rx, data_tx : std_logic_vector(7 downto 0);
signal numWords_bcd_internal : std_logic_vector(11 downto 0);


TYPE state_type IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, RX_A_3);   --define states in the state machine
SIGNAL curState, nextState: state_type;

begin
-------------------------------------------------------------------

combi_nextState: PROCESS(curState, valid)
begin
    case curState is
        when INIT =>
            if valid = '1' then
                nextState <= RX_INIT;
            else
                nextState <= INIT;
            end if;

        when RX_INIT =>
            if fe = '1' or oe = '1' then
                nextState <= RX_INIT;
            elsif data_rx = "01000001" or data_rx = "01100001" then --A or a
                nextState <= RX_A;
            elsif data_rx = "01010000" or data_rx = "01110000" then --P or p
                nextState <= RX_P;
            elsif data_rx = "01001100" or data_rx = "01101100" then --L or l
                nextState <= RX_L;
            else
                nextState <= RX_INIT;
            end if;             

        when RX_A =>
            if fe = '1' or oe = '1' then
                nextState <= RX_INIT;
            elsif data_rx < "00110000" or data_rx > "00111001" then --0 = "00110000" 9 = "00111001"
                nextState <= RX_INIT;                  
            else
                nextState <= RX_A_1;
                numWords_bcd_internal <= numWords_bcd_internal(11 downto 4) & data_rx(3 downto 0);
            end if;
        when RX_A_1 =>
            if fe = '1' or oe = '1' then
                nextState <= RX_INIT;
            elsif data_rx < "00110000" or data_rx > "00111001" then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_INIT;                  
            else
                nextState <= RX_A_2;
                numWords_bcd_internal <= numWords_bcd_internal(11 downto 8) & data_rx(3 downto 0) & numWords_bcd_internal(3 downto 0);
            end if;
        when RX_A_2 =>
            if fe = '1' or oe = '1' then
                nextState <= RX_INIT;
            elsif data_rx < "00110000" or data_rx > "00111001" then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_INIT;                  
            else
                nextState <= RX_A_3;
                numWords_bcd <= data_rx(3 downto 0) & numWords_bcd_internal(7 downto 0);
                start <= '1';
            end if;
        when others =>
            nextState <= INIT;
    end case;
end process; 
-------------------------------------------------------------------
seq_state: process (clk, reset)
begin
  if reset = '0' then
    curState <= INIT;
  elsif clk'event and clk='1' then
    curState <= nextState;
  end if;
end process; -- seq
-------------------------------------------------------------------
registers: process(clk)
begin
    if clk'event and clk='1' then
        data_rx <= rxData;
        oe <= ovErr;
        fe <= framErr;
        valid <= rxnow;
    else
        data_rx <= data_rx;
        oe <= oe;
        fe <= fe;
        valid <= valid;
    end if;
end process;
-------------------------------------------------------------------
combi_out: process(curState)
begin
end process; -- combi_output
-------------------------------------------------------------------

end Behavioral;
