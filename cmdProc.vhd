----------------------------------------------------------------------------------
-- Company: 
-- Engineer: B.Zhang
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
signal fe, fe_n: std_logic;   --internal signals with 1 bit
signal data_tx : std_logic_vector(7 downto 0); --internal signals with 8 bits
signal counter, counter_full: std_logic_vector(9 downto 0); -- maximum 999
signal numWords_bcd_reg, numWords_bcd_reg_n: BCD_ARRAY_TYPE(2 downto 0);

type state_type IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, dataConsumer_communication_A, tx_A_init, tx_A);   --define the state type
signal curState, nextState: state_type; --state variables

begin
numWords_bcd <= numWords_bcd_reg;
--------------State register combinational logic--------------------------
combi_nextState: PROCESS(curState, rxnow, rxData, seqDone, dataReady)
begin
    case curState is
        when INIT =>    --Initial state
            if rxnow = '1' then
                nextState <= RX_INIT;
            else
                nextState <= INIT;
            end if;
        when RX_INIT => --initial receiver state
            if fe = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData = "01000001" or rxData = "01100001" then --A or a
                nextState <= RX_A;
            elsif rxData = "01010000" or rxData = "01110000" then --P or p
                nextState <= RX_P;
            elsif rxData = "01001100" or rxData = "01101100" then --L or l
                nextState <= RX_L;
            else
                nextState <= RX_INIT;
            end if;             
        when RX_A =>    --receive first bit
            if fe = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_1;                  
            else
                nextState <= RX_A;
            end if;
        when RX_A_1 =>  --receive second bit
            if fe = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_2;                  
            else
                nextState <= RX_A_1;
            end if;
        when RX_A_2 =>  --receive third bit
            if fe = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= dataConsumer_communication_A;                  
            else
                nextState <= RX_A_2;
            end if;
        when dataConsumer_communication_A =>    
            if seqDone = '1' then
                nextState <= tx_A_init;
            elsif dataReady = '1' then
                nextState <= dataConsumer_communication_A;
            else
                nextState <= dataConsumer_communication_A;
            end if;
        when tx_A_init =>
            if txdone = '0' then
                nextState <= tx_A;
            else
                nextState <= tx_A_init;
            end if;
        when tx_A =>
            if counter = counter_full then
                nextState <= INIT;
            elsif txdone = '1' then
                nextState <= tx_A;
            else
                nextState <= tx_A;
            end if;
        when others =>
            nextState <= INIT;
    end case;
end process; 
---------------state register sequential logic----------------------------------
seq_state: process (clk, reset)
begin
  if reset = '1' then
    curState <= INIT;
  elsif clk'event and clk='1' then
    curState <= nextState;
  end if;
end process; -- seq
--------------fe register--------------------
combi_fe: process(framErr) --combinational logic
begin
        fe_n <= framErr;
end process;
seq_fe: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        fe <= '0';
    elsif clk'event and clk='1' then
        fe <= fe_n;
    end if;
end process; 
--------------numWords_bcd_reg_0 register--------------------
combi_numWords_bcd_reg_0: process(nextState, curState, reset) --combinational logic
begin
    if nextState = dataConsumer_communication_A and curState = RX_A_2 then
        numWords_bcd_reg_n(0) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(0) <= numWords_bcd_reg(0);
    end if;
end process;
seq_numWords_bcd_reg_0: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        numWords_bcd_reg(0) <= "0000";
    elsif clk'event and clk='1' then
        numWords_bcd_reg(0) <= numWords_bcd_reg_n(0);
    end if;
end process; 
--------------numWords_bcd_reg_1 register--------------------
combi_numWords_bcd_reg_1: process(nextState, curState, reset) --combinational logic
begin
    if nextState = RX_A_2 and curState = RX_A_1 then
        numWords_bcd_reg_n(1) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(1) <= numWords_bcd_reg(1);
    end if;
end process;
seq_numWords_bcd_reg_1: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        numWords_bcd_reg(1) <= "0000";
    elsif clk'event and clk='1' then
        numWords_bcd_reg(1) <= numWords_bcd_reg_n(1);
    end if;
end process; 
--------------numWords_bcd_reg_2 register--------------------
combi_numWords_bcd_reg_2: process(nextState, curState, reset) --combinational logic
begin
    if nextState = RX_A_1 and curState = RX_A then
        numWords_bcd_reg_n(2) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(2) <= numWords_bcd_reg(2);
    end if;
end process;
seq_numWords_bcd_reg_2: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        numWords_bcd_reg(2) <= "0000";
    elsif clk'event and clk='1' then
        numWords_bcd_reg(2) <= numWords_bcd_reg_n(2);
    end if;
end process;
----------rxdone output assignment process---------------------
seq_rxdone: process(nextState, curState)
begin
    rxdone <= '0';
        if nextState = RX_INIT and curState = INIT then
            rxdone <= '1';
        elsif nextState = RX_A and curState = RX_INIT then
            rxdone <= '1';
        elsif nextState = RX_A_1 and curState = RX_A then
            rxdone <= '1';
        elsif nextState = RX_A_2 and curState = RX_A_1 then
            rxdone <= '1';
        end if;
end process;
end Behavioral;
