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
signal txdata_reg_n_1, txdata_reg_n_2, txdata_reg_1, txdata_reg_2: std_logic_vector(7 downto 0); --internal signals with 8 bits
signal counter, counter_full: std_logic_vector(9 downto 0); -- maximum 999
signal numWords_bcd_reg, numWords_bcd_reg_n: BCD_ARRAY_TYPE(2 downto 0);

type state_type IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, dataConsumer_communication_A);   --define the state type
signal curState, nextState: state_type; --state variables
type state_type_tx IS (INIT, TX_START, TX_START_1, TX_START_2);   --define the state type for tx machine
signal curState_tx, nextState_tx: state_type_tx; --state variables for tx machine
type state_type_dataConsumer IS (INIT,DATACONSUMER_START,J_tx);   --define the state type for dataconsumer machine
signal curState_dataConsumer, nextState_dataConsumer: state_type_dataConsumer; --state variables for dataconsumer machine
begin
numWords_bcd <= numWords_bcd_reg;
--------------Main State register combinational logic--------------------------
combi_nextState_main: PROCESS(curState, rxnow, rxData, seqDone, dataReady)
begin
    case curState is
        when INIT =>    --Initial state
            if rxnow = '1' then
                nextState <= RX_INIT;
            else
                nextState <= INIT;
            end if;
        when RX_INIT => --initial receiver state
            if framErr = '1' and rxnow = '1' then
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
            if framErr = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_1;                  
            else
                nextState <= RX_A;
            end if;
        when RX_A_1 =>  --receive second bit
            if framErr = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_2;                  
            else
                nextState <= RX_A_1;
            end if;
        when RX_A_2 =>  --receive third bit
            if framErr = '1' and rxnow = '1' then
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
---------------Main state register sequential logic----------------------------------
seq_state_main: process (clk, reset)
begin
  if reset = '1' then
    curState <= INIT;
  elsif clk'event and clk='1' then
    curState <= nextState;
  end if;
end process; -- seq
--------------Tx State register combinational logic--------------------------
combi_nextState_tx: PROCESS(curState_tx, nextState, nextState_dataConsumer)
begin
    case curState_tx is
        when INIT =>    --Initial state
            if nextState_dataConsumer = J_tx then
                nextState_tx <= TX_START;
            else
                nextState_tx <= INIT;
            end if;
        when TX_START =>    --start to transmit
            if txDone = '1' then
                nextState_tx <= TX_START_1;
            else
                nextState_tx <= TX_START;
        when TX_START_1 =>    --start to transmit
            if txDone = '1' then
                nextState_tx <= TX_START_2;
            else
                nextState_tx <= TX_START_1;
        when others =>
            nextState_tx <= INIT;
    end case;
end process; 
---------------Tx state register sequential logic----------------------------------
seq_state_tx: process (clk, reset)
begin
  if reset = '1' then
    curState_tx <= INIT;
  elsif clk'event and clk='1' then
    curState_tx <= nextState_tx;
  end if;
end process; 
--------------dataConsumer State register combinational logic--------------------------
combi_nextState_dataConsumer: PROCESS(curState_dataConsumer, nextState, dataReady)
begin
    case curState_dataConsumer is
        when INIT =>    --Initial state
            if nextState = dataConsumer_communication_A then
                nextState_dataConsumer <= DATACONSUMER_START;
            else
                nextState_dataConsumer <= INIT;
            end if;
        when DATACONSUMER_START =>    --start to get data
            if dataReady = '1' then
                nextState_dataConsumer <= J_tx;
            else
                nextState_dataConsumer <= DATACONSUMER_START;
            end if;
        when J_tx =>
            nextState_dataConsumer <= J_tx;
        when others =>
            nextState_dataConsumer <= INIT;
    end case;
end process; 
---------------dataConsumer state register sequential logic----------------------------------
seq_state_dataConsumer: process (clk, reset)
begin
  if reset = '1' then
    curState_dataConsumer <= INIT;
  elsif clk'event and clk='1' then
    curState_dataConsumer <= nextState_dataConsumer;
  end if;
end process; -- seq
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
----------start output assignment process---------------------
seq_start: process(curState, nextState, dataReady)
begin
    start <= '0';
        if curState = RX_A_2 and nextState = dataConsumer_communication_A then
            start <= '1';
        elsif dataReady = '1' then
            start <= '0';
        end if;
end process;
--------------txdata register---------------------------------
combi_txdata_reg: process(dataReady) --combinational logic
begin
    if dataReady = '1' then
        if (byte(7 downto 4) <= "1001") then
            txdata_reg_n_1 <= "0000" & byte(7 downto 4) + "00110000";
        else
            txdata_reg_n_1 <= "0000" & byte(7 downto 4) + "00110111";
        end if;
        if (byte(3 downto 0) <= "1001") then
            txdata_reg_n_2 <= "0000" & byte(7 downto 4) + "00110000";
        else
            txdata_reg_n_2 <= "0000" & byte(7 downto 4) + "00110111";
        end if;
    else
        txdata_reg_n_1 <= txdata_reg_1;
        txdata_reg_n_2 <= txdata_reg_2;
    end if;
end process;
seq_txdata_reg: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        txdata_reg_1 <= "00000000";
        txdata_reg_2 <= "00000000";
    elsif clk'event and clk='1' then
        txdata_reg_1 <= txdata_reg_n_1;
        txdata_reg_2 <= txdata_reg_n_2;
    end if;
end process; 
end Behavioral;
----------txData output assignment process---------------------
seq_start: process(curState, nextState, dataReady)
begin
    start <= '0';
        if curState = RX_A_2 and nextState = dataConsumer_communication_A then
            start <= '1';
        elsif dataReady = '1' then
            start <= '0';
        end if;
end process;
--------------txdata register---------------------------------
