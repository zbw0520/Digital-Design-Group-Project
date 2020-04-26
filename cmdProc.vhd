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
signal txDone_reg, txDone_reg_n, en_counter_p, rxnow_reg, rxnow_reg_n, en_counter_l, en_counter_crlf, seqDone_reg, seqDone_reg_n, zeroflag, zeroflag_n, txNow_reg, txNow_reg_n: std_logic;
signal maxIndex_reg_bcd, maxIndex_reg_bcd_n: CHAR_ARRAY_TYPE(2 downto 0);
signal dataResults_reg_bcd, dataResults_reg_bcd_n: CHAR_ARRAY_TYPE(13 downto 0);
signal counter_l, counter_l_n: std_logic_vector(4 downto 0);
signal counter_crlf, counter_crlf_n: std_logic_vector(3 downto 0);

type state_type IS (INIT, RX_INIT, RX_A, RX_P_0, RX_P, RX_L_0, RX_L, RX_A_1, RX_A_2, dataConsumer_communication_A,dataConsumer_communication_A_0, dataConsumer_communication_P, dataConsumer_communication_L);   --define the state type
signal curState, nextState: state_type; --state variables
type state_type_tx IS (INIT, TX_START, TX_START_1, TX_START_2, J_dataConsumer, TX_P, TX_L, TX_crlf);   --define the state type for tx machine
signal curState_tx, nextState_tx: state_type_tx; --state variables for tx machine
type state_type_dataConsumer IS (INIT, DATACONSUMER_START_A, J_tx);   --define the state type for dataconsumer machine
signal curState_dataConsumer, nextState_dataConsumer: state_type_dataConsumer; --state variables for dataconsumer machine
type state_type_tx_ctrl IS(INIT, TX_START, TX_START_1, TX_END);
signal curState_tx_crlf, nextState_tx_crlf: state_type_tx_ctrl;
type state_type_echo IS (INIT, TX, TX_1, TX_CRLF, FINISH);   --define the state type
signal curState_echo, nextState_echo: state_type_echo; --state variables
begin
numWords_bcd <= numWords_bcd_reg;
txNow <= txNow_reg;
--------------Main State register combinational logic--------------------------
combi_nextState_main: PROCESS(curState, rxnow, rxData, seqDone_reg_n, rxnow_reg, framErr, counter_p, counter_l, curState_tx, txDone, curState_tx_crlf,zeroflag)
begin
    case curState is
        when INIT =>    --Initial state
            if rxnow = '1' and curState_tx /= TX_START then
                nextState <= RX_INIT;
            else 
                nextState <= INIT;
            end if;
        when RX_INIT => --initial receiver state
            if rxData = "01000001" or rxData = "01100001" then --A or a
                nextState <= RX_A;
            elsif (rxData = "01010000" or rxData = "01110000") and rxnow_reg = '0' then --P or p
                nextState <= RX_P_0;
            elsif (rxData = "01001100" or rxData = "01101100") and rxnow_reg = '0' then --L or l
                nextState <= RX_L_0;
            else
                nextState <= RX_INIT;
            end if;             
        when RX_A =>    --receive first bit
            if framErr = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_1;    
            elsif (rxData < "00110000" or rxData > "00111001") and rxnow = '1' then
                nextState <= RX_INIT;
            else
                nextState <= RX_A;
            end if;
        when RX_A_1 =>  --receive second bit
            if framErr = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData >= "00110000" and rxData <= "00111001" and rxnow = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= RX_A_2; 
            elsif (rxData < "00110000" or rxData > "00111001") and rxnow = '1' then
                nextState <= RX_INIT;
            else
                nextState <= RX_A_1;
            end if;
        when RX_A_2 =>  --receive third bit
            if framErr = '1' and rxnow = '1' then
                nextState <= RX_INIT;
            elsif rxData > "00110000" and rxData <= "00111001" and rxnow = '1' and txdone = '1' then  --0 = "00110000" 9 = "00111001"
                nextState <= dataConsumer_communication_A_0; 
            elsif rxData = "00110000" and zeroflag = '0' and rxnow = '1' and txdone = '1' then
                nextState <= dataConsumer_communication_A_0; 
            elsif rxData = "00110000" and zeroflag = '1' and rxnow = '1' then   
                nextState <= RX_INIT;
            elsif (rxData < "00110000" or rxData > "00111001") and rxnow = '1' then
                nextState <= RX_INIT;
            else
                nextState <= RX_A_2;
            end if;
        when dataConsumer_communication_A_0 =>
            if curState_tx_crlf = TX_END then
                nextState <= dataConsumer_communication_A;
            else 
                nextState <= dataConsumer_communication_A_0;
            end if;
        when dataConsumer_communication_A =>    
            if seqDone_reg_n = '1' then-----------------------
                nextState <= INIT;
            else
                nextState <= dataConsumer_communication_A;
            end if;
        when RX_P_0 =>
            if curState_tx_crlf = TX_END then
                nextState <= RX_P;
            else 
                nextState <= RX_P_0;
            end if;
        when RX_L_0 =>
            if curState_tx_crlf = TX_END then
                nextState <= RX_L;
            else 
                nextState <= RX_L_0;
            end if;
        when RX_P =>
            if counter_p = "111" then
                nextState <= INIT;
            else    
                nextState <= RX_P;
            end if;
        when RX_L =>
            if counter_l = "10101" then
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
    if rising_edge(clk) then
        if reset = '1' then
            curState <= INIT;
        else
            curState <= nextState;
        end if;
    end if;
end process; -- seq
--------------Tx State register combinational logic--------------------------
combi_nextState_tx: PROCESS(curState, nextState, curState_tx, curState_dataConsumer, txDone_reg, txDone, rxnow_reg, counter_l, counter_p, curState_tx_crlf,seqDone_reg_n)
begin
    case curState_tx is
        when INIT =>    --Initial state
            if curState_dataConsumer = J_tx then
                nextState_tx <= TX_START;
            elsif nextState=RX_P and rxnow_reg = '0' then
                nextState_tx <= TX_P;
            elsif nextState=RX_L and rxnow_reg = '0' then
                nextState_tx <= TX_L;
            else
                nextState_tx <= INIT;
            end if;
            
        when TX_START =>    --start to transmit
            if txDone_reg = '1' and txDone = '0' then
                nextState_tx <= TX_START_1;
            else
                nextState_tx <= TX_START;
            end if;
            
        when TX_START_1 =>    --start to transmit
            if txDone_reg = '1' and txDone = '0' then
                nextState_tx <= TX_START_2;
            else
                nextState_tx <= TX_START_1;
            end if;
            
        when TX_START_2 =>
            if txDone_reg = '1' and txDone = '0' then
                nextState_tx <= J_dataConsumer;
            elsif curState = INIT then
                nextState_tx <= TX_crlf;
            else
                nextState_tx <= TX_START_2;
            end if;
        when TX_crlf =>
            if curState_tx_crlf = TX_END then
                nextState_tx <= INIT;
            else
                nextState_tx <= TX_crlf;
            end if;
        when J_dataConsumer =>
            if curState_dataConsumer = J_tx or seqDone_reg_n = '1' or curState = INIT then
                nextState_tx <= INIT;
            else
                nextState_tx <= J_dataConsumer;
            end if;
            
        when TX_P =>
            if counter_p = "111" then
                nextState_tx <= TX_crlf;
            else 
                nextState_tx <= TX_P;         
            end if;
            
        when TX_L =>
            if counter_l = "10101" then
                nextState_tx <= TX_crlf;
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
if rising_edge(clk) then
    if reset = '1' then
        curState_tx <= INIT;
    else
        curState_tx <= nextState_tx;
    end if;
end if;
end process; 
--------------Tx_CRLF State register combinational logic--------------------------
combi_nextState_tx_crlf: PROCESS(curState_tx, txDone_reg, txDone, curState_tx_crlf, counter_crlf, curState_echo)
begin
    case curState_tx_crlf is
        when INIT =>    --Initial state
            if curState_tx = TX_CRLF or curState_echo = TX_CRLF then
                nextState_tx_crlf <= TX_START;
            else
                nextState_tx_crlf <= INIT;
            end if;
        when TX_START =>    --start to transmit
            if txDone_reg = '1' and txDone = '0' and counter_crlf < "1011" then
                nextState_tx_crlf <= TX_START;
            elsif txDone_reg = '1' and txDone = '0' and counter_crlf = "1011" then
                nextState_tx_crlf <= TX_END;
            else
                nextState_tx_crlf <= TX_START;
            end if;
        when TX_END =>
            nextState_tx_crlf <= INIT;
        when others =>
            nextState_tx_crlf <= INIT;
    end case;
end process; 
---------------Tx_CRLF state register sequential logic----------------------------------
seq_state_tx_crlf: process (clk, reset)
begin
if rising_edge(clk) then
    if reset = '1' then
        curState_tx_crlf <= INIT;
    else
        curState_tx_crlf <= nextState_tx_crlf;
    end if;
end if;
end process; 
--------------dataConsumer State register combinational logic--------------------------
combi_nextState_dataConsumer: PROCESS(curState_dataConsumer, curState, dataReady, curState_tx)
begin
    case curState_dataConsumer is
        when INIT =>    --Initial state
            if curState = dataConsumer_communication_A then
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
            if curState_tx = J_dataConsumer  or curState = INIT then
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
if rising_edge(clk) then
    if reset = '1' then
        curState_dataConsumer <= INIT;
    else
        curState_dataConsumer <= nextState_dataConsumer;
    end if;
end if;
end process; -- seq
--------------echo State register combinational logic--------------------------
combi_nextState_echo: PROCESS(curState_echo, curState, nextState, txDone_reg, txDone,curState_tx_crlf)  
begin
    case curState_echo is
        when INIT =>    --Initial state
            if curState = RX_INIT and nextState = RX_A then
                nextState_echo <= TX;
            elsif curState = RX_A and nextState = RX_A_1 then
                nextState_echo <= TX;
            elsif curState = RX_A_1 and nextState = RX_A_2 then
                nextState_echo <= TX;
            elsif (curState = RX_A_2 and nextState = dataConsumer_communication_A_0) or (curState = RX_INIT and (nextState = RX_P_0 or nextState = RX_L_0))then
                nextSTate_echo <= TX_1;
            else
                nextState_echo <= INIT;
            end if;
        when TX =>
            if txDone_reg = '0' and txDone = '1' then
                nextState_echo <= FINISH;
            else
                nextState_echo <= TX;
            end if;
        when TX_1 =>
            if txDone_reg = '0' and txDone = '1' then
                nextState_echo <= TX_CRLF;
            else
                nextState_echo <= TX_1;
            end if;
        when TX_CRLF =>
            if curState_tx_crlf = TX_END then
                nextState_echo <= FINISH;
            else
                nextState_echo <= TX_CRLF;
            end if;
        when FINISH =>
            nextState_echo <= INIT;
        when others =>
            nextState_echo <= INIT;
    end case;
end process; 
---------------echo state register sequential logic----------------------------------
seq_state_echo: process (clk, reset)
begin
if rising_edge(clk) then
    if reset = '1' then
        curState_echo <= INIT;
    else
        curState_echo <= nextState_echo;
    end if;
end if;
end process; -- seq
--------------numWords_bcd_reg_0 register--------------------
combi_numWords_bcd_reg_0: process(nextState, curState, rxData, numWords_bcd_reg(0)) --combinational logic
begin
    if (nextState = dataConsumer_communication_A_0 and curState = RX_A_2) or (nextState = dataConsumer_communication_A and curState = RX_A_2) then
        numWords_bcd_reg_n(0) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(0) <= numWords_bcd_reg(0);
    end if;
end process;
seq_numWords_bcd_reg_0: process (clk, reset) --sequential logic
begin
if rising_edge(clk) then
    if reset = '1' then
        numWords_bcd_reg(0) <= "0000";
    else
        numWords_bcd_reg(0) <= numWords_bcd_reg_n(0);
    end if;
end if;
end process; 
--------------numWords_bcd_reg_1 register--------------------
combi_numWords_bcd_reg_1: process(nextState, curState, rxData, numWords_bcd_reg(1)) --combinational logic
begin
    if nextState = RX_A_2 and curState = RX_A_1 then
        numWords_bcd_reg_n(1) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(1) <= numWords_bcd_reg(1);
    end if;
end process;
seq_numWords_bcd_reg_1: process (clk, reset) --sequential logic
begin
if rising_edge(clk) then
    if reset = '1' then
        numWords_bcd_reg(1) <= "0000";
    else
        numWords_bcd_reg(1) <= numWords_bcd_reg_n(1);
    end if;
end if;
end process; 
--------------numWords_bcd_reg_2 register--------------------
combi_numWords_bcd_reg_2: process(nextState, curState, rxData, numWords_bcd_reg(2)) --combinational logic
begin
    if nextState = RX_A_1 and curState = RX_A then
        numWords_bcd_reg_n(2) <= rxData(3 downto 0);
    else
        numWords_bcd_reg_n(2) <= numWords_bcd_reg(2);
    end if;
end process;
seq_numWords_bcd_reg_2: process (clk, reset) --sequential logic
begin
if rising_edge(clk) then
    if reset = '1' then
        numWords_bcd_reg(2) <= "0000";
    else
        numWords_bcd_reg(2) <= numWords_bcd_reg_n(2);
    end if;
end if;
end process;
----------rxdone output assignment process---------------------
combi_rxdone: process(rxnow, rxnow_reg)
begin
    rxdone <= '0';
        if rxnow = '1' and rxnow_reg = '0' then
            rxdone <= '1'; 
        end if;
end process;
----------start output assignment process---------------------
combi_start: process(curState_dataConsumer, dataReady)
begin
    start <= '0';
        if curState_dataConsumer = DATACONSUMER_START_A and dataReady /= '1' then
            start <= '1';
        end if;
end process;
--------------txdata register---------------------------------
combi_txdata_reg: process(dataReady, byte, txdata_reg_1, txdata_reg_2) --combinational logic
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
if rising_edge(clk) then
    if reset = '1' then
        txdata_reg_1 <= "00000000";
        txdata_reg_2 <= "00000000";
    else
        txdata_reg_1 <= txdata_reg_n_1;
        txdata_reg_2 <= txdata_reg_n_2;
    end if;
end if;
end process; 
----------txdata output assignment process---------------------
combi_txdata: process(curState_echo, curState_tx_crlf, curState_tx, counter_p, counter_crlf, counter_l_n, rxData, counter_l, txdata_reg_1, txdata_reg_2, dataResults_reg_bcd, maxIndex_reg_bcd, curState)
begin
    txData <= "00000000";
        if curState_tx = TX_START then
            txData <= txdata_reg_1;
        elsif curState_tx = TX_START_1 then
            txData <= txdata_reg_2;
        elsif curState_tx = TX_START_2 then
            txData <= "00100000";
        elsif curState_echo = TX or curState_echo = TX_1 then
            txData <= rxData;
        elsif curState_tx_crlf = TX_START and counter_crlf = "0001" then
            txData <= "00001101";
        elsif curState_tx_crlf = TX_START and counter_crlf = "0010" then
            txData <= "00001010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "0011" then    --00101010 = * 01100110 = f
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "0100" then    --00101010 = * 01110101 = u
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "0101" then    --00101010 = * 01100011 = c
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "0110" then    --00101010 = * 01101011 = k
            txData <= "00101010";
            
        elsif curState_tx_crlf = TX_START and counter_crlf = "0111" then    --00101010 = * 01111001 = y
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "1000" then    --00101010 = * 01101111 = o
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "1001" then    --00101010 = * 01110101 = u
            txData <= "00101010";
        elsif curState_tx_crlf = TX_START and counter_crlf = "1010" then
            txData <= "00001101";
        elsif curState_tx_crlf = TX_START and counter_crlf = "1011" then
            txData <= "00001010";
        elsif curState_tx = TX_P and (counter_p = "000" or counter_p = "001") then
            txData <= dataResults_reg_bcd(6); --output the first ascii byte of peak value------------------
        elsif curState_tx = TX_P and counter_p = "010" then
            txData <= dataResults_reg_bcd(7); --output the first ascii byte of peak value-----------------
        elsif curState_tx = TX_P and counter_p = "011" then
            txData <= "00100000"; --output the first ascii byte of peak value
        elsif curState_tx = TX_P and counter_p = "100" then
            txData <= maxIndex_reg_bcd(2); ----------------
        elsif curState_tx = TX_P and counter_p = "101" then
            txData <= maxIndex_reg_bcd(1); -----------------
        elsif curState_tx = TX_P and counter_p = "110" then
            txData <= maxIndex_reg_bcd(0); -----------------
        elsif curState_tx = TX_P and counter_p = "111" then
            txData <= "00100000";
     
        elsif curState_tx = TX_L and (counter_l_n = "00000" or counter_l_n = "00001") then
            txData <= dataResults_reg_bcd(12);-----------------
        elsif curState_tx = TX_L and counter_l = "00010" then
            txData <= dataResults_reg_bcd(13);-----------------
        elsif curState_tx = TX_L and counter_l = "00011" then
            txData <= "00100000";
        elsif curState_tx = TX_L and counter_l_n = "00100" then
            txData <= dataResults_reg_bcd(10);-----------------
        elsif curState_tx = TX_L and counter_l_n = "00101" then
            txData <= dataResults_reg_bcd(11);-----------------
        elsif curState_tx = TX_L and counter_l_n = "00110" then
            txData <= "00100000";
        elsif curState_tx = TX_L and counter_l_n = "00111" then
            txData <= dataResults_reg_bcd(8);-----------------
        elsif curState_tx = TX_L and counter_l_n = "01000" then
            txData <= dataResults_reg_bcd(9);-----------------
        elsif curState_tx = TX_L and counter_l_n = "01001" then
            txData <= "00100000";
        elsif curState_tx = TX_L and counter_l_n = "01010" then
            txData <= dataResults_reg_bcd(6);-----------------
        elsif curState_tx = TX_L and counter_l_n = "01011" then
            txData <= dataResults_reg_bcd(7);-----------------
        elsif curState_tx = TX_L and counter_l_n = "01100" then
            txData <= "00100000";
        elsif curState_tx = TX_L and counter_l_n = "01101" then
            txData <= dataResults_reg_bcd(4); -----------------
        elsif curState_tx = TX_L and counter_l_n = "01110" then
            txData <= dataResults_reg_bcd(5);-----------------
        elsif curState_tx = TX_L and counter_l_n = "01111" then
            txData <= "00100000"; 
        elsif curState_tx = TX_L and counter_l_n = "10000" then
            txData <= dataResults_reg_bcd(2);-----------------
        elsif curState_tx = TX_L and counter_l_n = "10001" then
            txData <= dataResults_reg_bcd(3);-----------------
        elsif curState_tx = TX_L and counter_l_n = "10010" then
            txData <= "00100000";
        elsif curState_tx = TX_L and counter_l_n = "10011" then
            txData <= dataResults_reg_bcd(0); -----------------
        elsif curState_tx = TX_L and counter_l_n = "10100" then
            txData <= dataResults_reg_bcd(1);-----------------
        elsif curState_tx = TX_L and counter_l_n = "10101" then
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
if rising_edge(clk) then
    if reset = '1' then
        txDone_reg <= '0';
    else
        txDone_reg <= txDone_reg_n;
    end if;
end if;
end process;
--------------txNow register--------------------
combi_txNow_reg: process(txNow_reg, reset, curState_tx, txdone, curState_echo, txDone_reg, curState_tx_crlf) --combinational logic
begin
    txNow_reg_n <= '0';
        if curState_tx = TX_START and txdone = '1' then
            txNow_reg_n <= '1';
        elsif curState_tx = TX_START_1 and txdone = '1' then
            txNow_reg_n <= '1';
        elsif curState_tx = TX_START_2 and txdone = '1' then
            txNow_reg_n <= '1';
        elsif curState_tx = TX_P and txdone = '1' then
            txNow_reg_n <= '1';
        elsif curState_tx = TX_L and txdone = '1' then
            txNow_reg_n <= '1';
        elsif curState_tx_crlf = TX_START and txdone = '1' then
            txNow_reg_n <= '1';
        elsif (curState_echo = TX or curState_echo = TX_1) and txdone = '1' and txDone_reg = '1' then
            txNow_reg_n <= '1';
        end if;
end process;
seq_txNow_reg: process (clk, reset) --sequential logic
begin
if rising_edge(clk) then
    if reset = '1' then
        txNow_reg <= '0';
    else
        txNow_reg <= txNow_reg_n;
    end if;
end if;
end process; 
--------------dataResults register--------------------
combi_dataResults: process(seqDone, dataResults, dataResults_reg_bcd) --combinational logic
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
if rising_edge(clk) then
    if reset = '1' then
        dataResults_reg_bcd(0) <= "00110000";   --high 4 bits
        dataResults_reg_bcd(1) <= "00110000";   --low 4 bits
        
        dataResults_reg_bcd(2) <= "00110000";
        dataResults_reg_bcd(3) <= "00110000";
        
        dataResults_reg_bcd(4) <= "00110000";
        dataResults_reg_bcd(5) <= "00110000";
        
        dataResults_reg_bcd(6) <= "00110000";
        dataResults_reg_bcd(7) <= "00110000";
        
        dataResults_reg_bcd(8) <= "00110000";
        dataResults_reg_bcd(9) <= "00110000";
        
        dataResults_reg_bcd(10) <= "00110000";
        dataResults_reg_bcd(11) <= "00110000";
        
        dataResults_reg_bcd(12) <= "00110000";
        dataResults_reg_bcd(13) <= "00110000";
    else
        dataResults_reg_bcd <= dataResults_reg_bcd_n;
    end if;
end if;
end process;
--------------maxIndex_bcd register--------------------
combi_maxIndex_reg_bcd: process(seqDone, maxIndex, maxIndex_reg_bcd) --combinational logic 
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
    if rising_edge(clk) then
        if reset = '1' then
            maxIndex_reg_bcd(0) <= "00110000";
            maxIndex_reg_bcd(1) <= "00110000";
            maxIndex_reg_bcd(2) <= "00110000";
        else    
            maxIndex_reg_bcd <= maxIndex_reg_bcd_n;
        end if;
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
combi_en_counter_p: process(curState_tx, txdone, txNow_reg)
begin
    en_counter_p <= '0';
        if curState_tx = TX_P and txdone = '1' and txNow_reg = '0' then
            en_counter_p <= '1';
        end if;
end process;
--------------counter for crlf--------------------
combi_counter_crlf: process(en_counter_crlf, counter_crlf, reset) --combinational logic
begin
    if counter_crlf = "1100" then
        counter_crlf_n <= "0000"; 
    elsif en_counter_crlf = '0' or reset = '1' then
        counter_crlf_n <= counter_crlf;      
    else
        counter_crlf_n <= counter_crlf + 1;
    end if;
end process;
seq_counter_crlf: process (clk, reset) --sequential logic
begin
    if rising_edge(clk) then
        if reset = '1' then
            counter_crlf <= "0000";
        else    
            counter_crlf <= counter_crlf_n;
        end if;
    end if;
end process;
----------en_counter_p assignment process---------------------
combi_en_counter_crlf: process(curState_tx_crlf, txdone, txNow_reg)
begin
    en_counter_crlf <= '0';
        if curState_tx_crlf = TX_START and txdone = '1' and txNow_reg = '0' then
            en_counter_crlf <= '1';
        end if;
end process;
--------------rxnow register--------------------        rxnow_reg_n = '1' and rxnow_reg = '0' --rising edge
combi_rxnow_reg: process(rxnow) --combinational logic
begin
    rxnow_reg_n <= rxnow;
end process;
seq_rxnow_reg: process (clk, reset) --sequential logic
begin
    if rising_edge(clk) then
        if reset = '1' then
            rxnow_reg <= '0';
        else    
            rxnow_reg <= rxnow_reg_n;
        end if;
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
combi_en_counter_l: process(curState_tx, txdone, txNow_reg)
begin
    en_counter_l <= '0';
        if curState_tx = TX_L and txdone = '1' and txNow_reg = '0' then
            en_counter_l <= '1';
        end if;
end process;
--------------seqDone register--------------------
combi_seqDone: process(seqDone,reset) --combinational logic
begin
    if reset = '1' then
        seqDone_reg_n <= '0';
    else
        seqDone_reg_n <= seqDone;
    end if;
end process;
seq_seqDone: process (clk, reset) --sequential logic 
begin
    if rising_edge(clk) then
        if reset = '1' then
            seqDone_reg <= '0';
        else
            seqDone_reg <= seqDone_reg_n;
        end if;
    end if;
end process;
--------------zeroflag register--------------------
combi_zeroflag: process(curState, rxData, zeroflag, reset) --combinational logic
begin
    if reset = '1' then
        zeroflag_n <= '0';
    elsif curState = RX_A and rxData = "00000000" then
        zeroflag_n <= '1';
    elsif zeroflag = '1' and curState = RX_A_1 then
        if rxData = "00110000" then
            zeroflag_n <= '1';
        else
            zeroflag_n <= '0';
        end if;
    elsif zeroflag = '1' and curState = RX_A_2 then
        if rxData = "00110000" then
            zeroflag_n <= '1';
        else
            zeroflag_n <= '0';
        end if;
    elsif curState /= RX_A and curState /= RX_A_1 and curState /= RX_A_2 then
        zeroflag_n <= '1';
    else
        zeroflag_n <= zeroflag;
    end if;
end process;
seq_zeroflag: process (clk, reset) --sequential logic 
begin
    if rising_edge(clk) then
        if reset = '1' then
            zeroflag <= '0';
        else
            zeroflag <= zeroflag_n;
        end if;
    end if;
end process;
end Behavioral;
