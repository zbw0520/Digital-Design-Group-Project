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
use ieee.std_logic_unsigned.all;
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
signal counter_p, counter_p_n: std_logic_vector(2 downto 0);
signal numWords_bcd_reg, numWords_bcd_reg_n: BCD_ARRAY_TYPE(2 downto 0);
signal txDone_reg, txDone_reg_n, en_counter_p, rxnow_reg, rxnow_reg_n, en_counter_l: std_logic;
signal maxIndex_reg_bcd, maxIndex_reg_bcd_n: CHAR_ARRAY_TYPE(2 downto 0);
signal dataResults_reg_bcd, dataResults_reg_bcd_n: CHAR_ARRAY_TYPE(13 downto 0);
signal counter_l, counter_l_n: std_logic_vector(4 downto 0);

type state_type IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, dataConsumer_communication_A, dataConsumer_communication_P, dataConsumer_communication_L);   --define the state type
signal curState, nextState: state_type; --state variables
type state_type_tx IS (INIT, TX_START, TX_START_1, TX_START_2, J_dataConsumer, TX_P, TX_L);   --define the state type for tx machine
signal curState_tx, nextState_tx: state_type_tx; --state variables for tx machine
type state_type_dataConsumer IS (INIT, DATACONSUMER_START_A, DATACONSUMER_START_P, DATACONSUMER_START_L, J_tx);   --define the state type for dataconsumer machine
signal curState_dataConsumer, nextState_dataConsumer: state_type_dataConsumer; --state variables for dataconsumer machine
begin
numWords_bcd <= numWords_bcd_reg;
--------------Main State register combinational logic--------------------------
combi_nextState_main: PROCESS(curState, rxnow, rxData, seqDone, rxnow_reg_n, rxnow_reg, dataReady, framErr, nextState_tx, curState_tx)
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
            elsif (rxData = "01010000" or rxData = "01110000") and (rxnow_reg_n = '1' and rxnow_reg = '0')then --P or p
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
                nextState <= INIT;
            else
                nextState <= dataConsumer_communication_A;
            end if;
        when RX_P =>
            if counter_p = "111" then
                nextState <= INIT;
            else    
                nextState <= RX_P;
            end if;
        when RX_L =>
            if counter_l = "10100" then
                nextState <= INIT;
            else
                nextState <= RX_L;
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
combi_nextState_tx: PROCESS(nextState, curState_tx, nextState_dataConsumer, txDone_reg, txDone_reg_n, rxnow_reg_n, rxnow_reg, counter_l, counter_p)
begin
    case curState_tx is
        when INIT =>    --Initial state
            if nextState_dataConsumer = J_tx then
                nextState_tx <= TX_START;
            elsif nextState=RX_P and (rxnow_reg_n = '1' and rxnow_reg = '0')then
                nextState_tx <= TX_P;
            elsif nextState=RX_L and (rxnow_reg_n = '1' and rxnow_reg = '0')then
                nextState_tx <= TX_L;
            else
                nextState_tx <= INIT;
            end if;
        when TX_START =>    --start to transmit
            if txDone_reg = '1' and txDone_reg_n = '0' then
                nextState_tx <= TX_START_1;
            else
                nextState_tx <= TX_START;
            end if;
        when TX_START_1 =>    --start to transmit
            if txDone_reg = '1' and txDone_reg_n = '0' then
                nextState_tx <= TX_START_2;
            else
                nextState_tx <= TX_START_1;
            end if;
        when TX_START_2 =>
            if txDone_reg = '1' and txDone_reg_n = '0' then
                nextState_tx <= J_dataConsumer;
            else
                nextState_tx <= TX_START_2;
            end if;
        when J_dataConsumer =>
            if nextState_dataConsumer = J_tx then
                nextState_tx <= INIT;
            else
                nextState_tx <= J_dataConsumer;
            end if;
        when TX_P =>
            if counter_p = "111" then
                nextState_tx <= INIT;
            else 
                nextState_tx <= TX_P;         
            end if;
        when TX_L =>
            if counter_l = "10101" then
                nextState_tx <= INIT;
            else 
                nextState_tx <= TX_L;         
            end if;
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
combi_nextState_dataConsumer: PROCESS(curState_dataConsumer, nextState, dataReady, nextState_tx)
begin
    case curState_dataConsumer is
        when INIT =>    --Initial state
            if nextState = dataConsumer_communication_A then
                nextState_dataConsumer <= DATACONSUMER_START_A;
            else
                nextState_dataConsumer <= INIT;
            end if;
        when DATACONSUMER_START_A =>    --start to get data
            if dataReady = '1' then
                nextState_dataConsumer <= J_tx;
            else
                nextState_dataConsumer <= DATACONSUMER_START_A;
            end if;
        when J_tx =>
            if nextState_tx = J_dataConsumer  or nextState = INIT then
                nextState_dataConsumer <= INIT;
            else
                nextState_dataConsumer <= J_tx;
            end if;            
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
combi_numWords_bcd_reg_0: process(nextState, curState) --combinational logic
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
combi_numWords_bcd_reg_1: process(nextState, curState) --combinational logic
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
combi_numWords_bcd_reg_2: process(nextState, curState) --combinational logic
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
seq_start: process(curState, nextState, curState_dataConsumer, nextState_dataConsumer, seqDone)
begin
    start <= '0';
        if seqDone = '0' and ((curState = RX_A_2 and nextState = dataConsumer_communication_A) or(curState_dataConsumer = J_tx and nextState_dataConsumer = INIT))then
            start <= '1';
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
            txdata_reg_n_2 <= "0000" & byte(3 downto 0) + "00110000";
        else
            txdata_reg_n_2 <= "0000" & byte(3 downto 0) + "00110111";
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
----------txdata output assignment process---------------------
seq_txdata: process(nextState_tx, counter_p_n, counter_l_n)
begin
    txData <= "00000000";
        if nextState_tx = TX_START then
            txData <= txdata_reg_n_1;
        elsif nextState_tx = TX_START_1 then
            txData <= txdata_reg_n_2;
        elsif nextState_tx = TX_START_2 then
            txData <= "00100000";
        elsif nextState_tx = TX_P and (counter_p_n = "000" or counter_p_n = "001") then
            txData <= dataResults_reg_bcd_n(6); --output the first ascii byte of peak value
        elsif nextState_tx = TX_P and counter_p_n = "010" then
            txData <= dataResults_reg_bcd_n(7); --output the first ascii byte of peak value
        elsif nextState_tx = TX_P and counter_p_n = "011" then
            txData <= "00100000"; --output the first ascii byte of peak value
        elsif nextState_tx = TX_P and counter_p_n = "100" then
            txData <= maxIndex_reg_bcd_n(2); 
        elsif nextState_tx = TX_P and counter_p_n = "101" then
            txData <= maxIndex_reg_bcd_n(1); 
        elsif nextState_tx = TX_P and counter_p_n = "110" then
            txData <= maxIndex_reg_bcd_n(0); 
        elsif nextState_tx = TX_P and counter_p_n = "111" then
            txData <= "00100000";
        elsif nextState_tx = TX_L and (counter_l_n = "00000" or counter_l_n = "00001") then
            txData <= dataResults_reg_bcd_n(0); 
        elsif nextState_tx = TX_L and counter_l_n = "00010" then
            txData <= dataResults_reg_bcd_n(1);
        elsif nextState_tx = TX_L and counter_l_n = "00011" then
            txData <= "00100000"; 
        elsif nextState_tx = TX_L and counter_l_n = "00100" then
            txData <= dataResults_reg_bcd_n(2);
        elsif nextState_tx = TX_L and counter_l_n = "00101" then
            txData <= dataResults_reg_bcd_n(3);
        elsif nextState_tx = TX_L and counter_l_n = "00110" then
            txData <= "00100000";
        elsif nextState_tx = TX_L and counter_l_n = "00111" then
            txData <= dataResults_reg_bcd_n(4); 
        elsif nextState_tx = TX_L and counter_l_n = "01000" then
            txData <= dataResults_reg_bcd_n(5);
        elsif nextState_tx = TX_L and counter_l_n = "01001" then
            txData <= "00100000"; 
        elsif nextState_tx = TX_L and counter_l_n = "01010" then
            txData <= dataResults_reg_bcd_n(6);
        elsif nextState_tx = TX_L and counter_l_n = "01011" then
            txData <= dataResults_reg_bcd_n(7);
        elsif nextState_tx = TX_L and counter_l_n = "01100" then
            txData <= "00100000";
        elsif nextState_tx = TX_L and counter_l_n = "01101" then
            txData <= dataResults_reg_bcd_n(8);
        elsif nextState_tx = TX_L and counter_l_n = "01110" then
            txData <= dataResults_reg_bcd_n(9);
        elsif nextState_tx = TX_L and counter_l_n = "01111" then
            txData <= "00100000";
        elsif nextState_tx = TX_L and counter_l_n = "10000" then
            txData <= dataResults_reg_bcd_n(10);
        elsif nextState_tx = TX_L and counter_l_n = "10001" then
            txData <= dataResults_reg_bcd_n(11);
        elsif nextState_tx = TX_L and counter_l_n = "10010" then
            txData <= "00100000";
        elsif nextState_tx = TX_L and counter_l_n = "10011" then
            txData <= dataResults_reg_bcd_n(12);
        elsif nextState_tx = TX_L and counter_l_n = "10100" then
            txData <= dataResults_reg_bcd_n(13);
        elsif nextState_tx = TX_L and counter_l_n = "10101" then
            txData <= "00100000";
        end if;
end process;
--------------txDone register--------------------
combi_txDone: process(txDone) --combinational logic
begin
    txDone_reg_n <= txDone;
end process;
seq_txDone: process (clk, reset) --sequential logic txDone_reg = '0' and txDone_reg_n = '1'--risingedge
begin
    if reset = '1' then
        txDone_reg <= '0';
    elsif clk'event and clk='1' then
        txDone_reg <= txDone_reg_n;
    end if;
end process;
----------txnow output assignment process---------------------
seq_txnow: process(curState_tx, txdone)
begin
    txnow <= '0';
        if curState_tx = TX_START and txdone = '1' then
            txNow <= '1';
        elsif curState_tx = TX_START_1 and txdone = '1' then
            txNow <= '1';
        elsif curState_tx = TX_START_2 and txdone = '1' then
            txNow <= '1';
        elsif curState_tx = TX_P and txdone = '1' then
            txNow <= '1';
        elsif curState_tx = TX_L and txdone = '1' then
            txNow <= '1';
        end if;
end process;
--------------dataResults register--------------------
combi_dataResults: process(seqDone) --combinational logic
begin
    if seqDone = '1' then
        if (dataResults(0)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(0) <= "0000" & dataResults(0)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(0) <= "0000" & dataResults(0)(7 downto 4) + "00110111";
        end if;
        if (dataResults(0)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(1) <= "0000" & dataResults(0)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(1) <= "0000" & dataResults(0)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(1)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(2) <= "0000" & dataResults(1)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(2) <= "0000" & dataResults(1)(7 downto 4) + "00110111";
        end if;
        if (dataResults(1)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(3) <= "0000" & dataResults(1)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(3) <= "0000" & dataResults(1)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(2)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(4) <= "0000" & dataResults(2)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(4) <= "0000" & dataResults(2)(7 downto 4) + "00110111";
        end if;
        if (dataResults(2)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(5) <= "0000" & dataResults(2)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(5) <= "0000" & dataResults(2)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(3)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(6) <= "0000" & dataResults(3)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(6) <= "0000" & dataResults(3)(7 downto 4) + "00110111";
        end if;
        if (dataResults(3)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(7) <= "0000" & dataResults(3)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(7) <= "0000" & dataResults(3)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(4)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(8) <= "0000" & dataResults(4)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(8) <= "0000" & dataResults(4)(7 downto 4) + "00110111";
        end if;
        if (dataResults(4)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(9) <= "0000" & dataResults(4)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(9) <= "0000" & dataResults(4)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(5)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(10) <= "0000" & dataResults(5)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(10) <= "0000" & dataResults(5)(7 downto 4) + "00110111";
        end if;
        if (dataResults(5)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(11) <= "0000" & dataResults(5)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(11) <= "0000" & dataResults(5)(3 downto 0) + "00110111";
        end if;
        -------------------------------------
        if (dataResults(6)(7 downto 4) <= "1001") then
            dataResults_reg_bcd_n(12) <= "0000" & dataResults(6)(7 downto 4) + "00110000";
        else
            dataResults_reg_bcd_n(12) <= "0000" & dataResults(6)(7 downto 4) + "00110111";
        end if;
        if (dataResults(6)(3 downto 0) <= "1001") then
            dataResults_reg_bcd_n(13) <= "0000" & dataResults(6)(3 downto 0) + "00110000";
        else
            dataResults_reg_bcd_n(13) <= "0000" & dataResults(6)(3 downto 0) + "00110111";
        end if;
    else
        dataResults_reg_bcd_n <= dataResults_reg_bcd;
    end if;
end process;
seq_dataResults: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        dataResults_reg_bcd(0) <= "00000000";   --high 4 bits
        dataResults_reg_bcd(1) <= "00000000";   --low 4 bits
        
        dataResults_reg_bcd(2) <= "00000000";
        dataResults_reg_bcd(3) <= "00000000";
        
        dataResults_reg_bcd(4) <= "00000000";
        dataResults_reg_bcd(5) <= "00000000";
        
        dataResults_reg_bcd(6) <= "00000000";
        dataResults_reg_bcd(7) <= "00000000";
        
        dataResults_reg_bcd(8) <= "00000000";
        dataResults_reg_bcd(9) <= "00000000";
        
        dataResults_reg_bcd(10) <= "00000000";
        dataResults_reg_bcd(11) <= "00000000";
        
        dataResults_reg_bcd(12) <= "00000000";
        dataResults_reg_bcd(13) <= "00000000";
    elsif clk'event and clk='1' then
        dataResults_reg_bcd <= dataResults_reg_bcd_n;
    end if;
end process;
--------------maxIndex_bcd register--------------------
combi_maxIndex_reg_bcd: process(seqDone) --combinational logic
begin
    if seqDone = '1' then
        -------------------------------------
        if (maxIndex(2) <= "1001") then
            maxIndex_reg_bcd_n(2) <= "0000" & maxIndex(2) + "00110000";
        else
            maxIndex_reg_bcd_n(2) <= "0000" & maxIndex(2) + "00110111";
        end if;
        -------------------------------------
        if (maxIndex(1)(3 downto 0) <= "1001") then
            maxIndex_reg_bcd_n(1) <= "0000" & maxIndex(1) + "00110000";
        else
            maxIndex_reg_bcd_n(1) <= "0000" & maxIndex(1) + "00110111";
        end if;
        -------------------------------------
        if (maxIndex(0) <= "1001") then
            maxIndex_reg_bcd_n(0) <= "0000" & maxIndex(0) + "00110000";
        else
            maxIndex_reg_bcd_n(0) <= "0000" & maxIndex(0) + "00110111";
        end if;
    else
        maxIndex_reg_bcd_n <= maxIndex_reg_bcd;
    end if;
end process;
seq_maxIndex: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        maxIndex_reg_bcd(0) <= "00000000";
        maxIndex_reg_bcd(1) <= "00000000";
        maxIndex_reg_bcd(2) <= "00000000";
    elsif clk'event and clk='1' then
        maxIndex_reg_bcd <= maxIndex_reg_bcd_n;
    end if;
end process;
--------------counter for P--------------------
combi_counter_p: process(en_counter_p, counter_p, reset) --combinational logic
begin
    if counter_p = "111"  then
        counter_p_n <= "000"; 
    elsif en_counter_p = '0' or reset = '1' then
        counter_p_n <= counter_p;      
    else
        counter_p_n <= counter_p + 1;
    end if;
end process;
seq_counter_p: process (clk, reset) --sequential logic
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter_p <= "000";
        else    
            counter_p <= counter_p_n;
        end if;
    end if;
end process;
----------en_counter_p assignment process---------------------
seq_en_counter_p: process(curState_tx, txdone)
begin
    en_counter_p <= '0';
        if curState_tx = TX_P and txdone = '1' then
            en_counter_p <= '1';
        end if;
end process;
--------------rxnow register--------------------        rxnow_reg_n = '1' and rxnow_reg = '0' --rising edge
combi_rxnow_reg: process(rxnow) --combinational logic
begin
    rxnow_reg_n <= rxnow;
end process;
seq_rxnow_reg: process (clk, reset) --sequential logic
begin
    if reset = '1' then
        rxnow_reg <= '0';
    elsif clk'event and clk='1' then
        rxnow_reg <= rxnow_reg_n;
    end if;
end process;
--------------counter for L--------------------
combi_counter_l: process(en_counter_l, counter_l, reset) --combinational logic
begin
    if counter_l = "10101"  then
        counter_l_n <= "00000"; 
    elsif en_counter_l = '0' or reset = '1' then
        counter_l_n <= counter_l;    
    else
        counter_l_n <= counter_l + 1;
    end if;
end process;
seq_counter_l: process (clk, reset) --sequential logic
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter_l <= "00000";
        else    
            counter_l <= counter_l_n;
        end if;
    end if;
end process; 
----------en_counter_l assignment process---------------------
seq_en_counter_l: process(curState_tx, txdone)
begin
    en_counter_l <= '0';
        if curState_tx = TX_L and txdone = '1' then
            en_counter_l <= '1';
        end if;
end process;
end Behavioral;
