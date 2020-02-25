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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
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
          reset : in std_logic; --synchronous reset
          rxnow : in std_logic;     --valid 
          rxData : in std_logic_vector (7 downto 0);    --data_rx
          txData : out std_logic_vector (7 downto 0);   --data_tx
          rxdone : out std_logic;   --done
          ovErr : in std_logic; --oe
          framErr : in std_logic;   --fe
          txnow : out std_logic;    --txNow
          txdone : in std_logic;    --txDone
          start : out std_logic;    --start_cmd
          numWords_bcd : out BCD_ARRAY_TYPE(2 downto 0);    --numWords \numWords_bcd[0]\ => numWords_bcd(0): out STD_LOGIC_VECTOR ( 3 downto 0 ); from <cmd_synthesis.vhd>
          dataReady : in std_logic; --data_R
          byte : in std_logic_vector(7 downto 0);   --byte
          maxIndex : in BCD_ARRAY_TYPE(2 downto 0); --maxIndex
          dataResults : in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1); --dataResults
          seqDone : in std_logic    --seq_done, asserted after all data generated, and turn low a clock cycle later 
        );
end cmdProc;

architecture Behavioral of cmdProc is
signal oe, fe, valid : std_logic;
signal data_rx, data_tx : std_logic_vector(7 downto 0);
signal numWords_bcd_internal : std_logic_vector(11 downto 0);
signal numWords_bcd_array: BCD_ARRAY_TYPE(2 downto 0);
signal done : std_logic;
signal seq_done : std_logic;
signal P_flag, L_flag : std_logic; --the flag for the start of the peak and L output process
signal num_count : std_logic_vector(9 downto 0);    --count the number of data transmitted
signal start_cmd : std_logic;
signal data_R : std_logic;

--we may need two state machines for receiver and transmitter seperately
TYPE state_type_rx IS (INIT, RX_INIT, RX_A, RX_P, RX_L, RX_A_1, RX_A_2, RX_A_3);   --define states in the Rx state machine
TYPE state_type_tx IS (IDLE);   --define states in the Tx state machine
SIGNAL curState_rx, nextState_rx: state_type_rx;
SIGNAL curState_tx, nextState_tx: state_type_tx;

begin
-------------------------------------------------------------------

Rx_combi_nextState: PROCESS(curState_rx, valid)
begin
    case curState_rx is
        when INIT =>
            num_count <= "0000000000";
            P_flag <= '0';
            L_flag <= '0';
            if valid = '1' then
                nextState_rx <= RX_INIT;
            else
                nextState_rx <= INIT;
            end if;

        when RX_INIT =>
            done <= '0';
            if valid = '1' then --check if the input is valid, if valid then read the data
                if fe = '1' or oe = '1' then
                    done <= '1'; --if the input is wrong, skip it and tell Rx to give another one
                    nextState_rx <= RX_INIT;
                elsif data_rx = "01000001" or data_rx = "01100001" then --A or a
                    done <= '1';
                    nextState_rx <= RX_A;
                elsif data_rx = "01010000" or data_rx = "01110000" then --P or p
                    done <= '1';
                    nextState_rx <= RX_P;
                elsif data_rx = "01001100" or data_rx = "01101100" then --L or l
                    done <= '1';
                    nextState_rx <= RX_L;
                else
                    done <= '1'; --if the input is not a,p,l, skip it and ask for another one
                    nextState_rx <= RX_INIT;
                end if;
            else
                nextState_rx <= RX_INIT; --if the input is not ready, just wait
            end if;
                                
        when RX_A =>
                done <= '0'; --after being high for one clock cycle, pull it down
                if valid = '1' then
                    if fe = '1' or oe = '1' then
                        done <= '1'; --if the input is wrong, skip it and tell Rx to give another one
                        nextState_rx <= RX_INIT;
                    elsif data_rx < "00110000" or data_rx > "00111001" then --0 = "00110000" 9 = "00111001"
                        nextState_rx <= RX_INIT;                  
                    else
                        done <= '1'; --this's a valid number, tell Rx to prepare for next input
                        nextState_rx <= RX_A_1;
                        numWords_bcd_internal(11 downto 8) <= data_rx(3 downto 0); --the first input should be the most significant value
                    end if;
                else
                    nextState_rx <= RX_A;
                end if;
                               
        when RX_A_1 =>
            done <= '0';
            if valid = '1' then
                if fe = '1' or oe = '1' then
                    done <= '1';
                    nextState_rx <= RX_INIT;
                elsif data_rx < "00110000" or data_rx > "00111001" then  --0 = "00110000" 9 = "00111001"
                    nextState_rx <= RX_INIT;                  
                else
                    done <= '1';
                    nextState_rx <= RX_A_2;
                    numWords_bcd_internal(7 downto 4) <= data_rx(3 downto 0);
                end if;                   
            else
                nextState_rx <= RX_A_1;
            end if;
            
        when RX_A_2 =>
            done <= '0';
            if valid = '1' then
                if fe = '1' or oe = '1' then
                    done <= '1';
                    nextState_rx <= RX_INIT;
                elsif data_rx < "00110000" or data_rx > "00111001" then  --0 = "00110000" 9 = "00111001"
                    nextState_rx <= RX_INIT;                  
                else
                    done <= '0'; --the last BCD data has been received, which means the trasmitting process is starting hence the receiving process must be halt(done <= '0')
                    nextState_rx <= RX_A_3;
                    numWords_bcd_internal(3 downto 0) <= data_rx(3 downto 0);                                       
                end if;
            else
                nextState_rx <= RX_A_2;
            end if;
            
        when RX_A_3 =>
            done <= '0';        
            if seq_done = '0' then --check if the DataConsumer has finished the process
                start_cmd <= '1';      --keep the 'start' high to keep data retrival
                nextState_rx <= RX_A_3; 
            else                    --after the 'seqDone' being asserted for 1 clock cycle, back to the initial state and wait for next a,p,l command
                start_cmd <= '0';       --after Axxx being readed and the cmd is transmitting, Rx should be blocked which means 'done' has to be 0 until Axxx are all transmitted, so we need a counter
                nextState_rx <= RX_INIT; 
            end if;
            
        when RX_P =>    --set a peak flag for transmitting process
            done <= '0';
            P_flag <= '1';  
            nextState_rx <= RX_INIT;
            
        when RX_L =>
            done <= '0';
            L_flag <= '1';
            nextState_rx <= RX_INIT;
                      
        when others =>
            nextState_rx <= INIT;
    end case;
end process; 
-------------------------------------------------------------------
VECtoBCD:process(numWords_bcd_internal)     --turn the vector to numWord_bcd, which is a 2-D arrary, by the way, get the total number of data for counting
variable tmp: integer range 0 to 1000:=0;
begin   
    for i in 0 to 2 loop
        numWords_bcd_array(i) <= numWords_bcd_internal((3+i*4) downto (0+i*4)); --get the 2-D arrary
        tmp := 10*tmp + conv_integer(numWords_bcd_internal((3+(2-i)*4) downto (0+(2-i)*4))); --turn the vector to integer
    end loop;
    num_count <= conv_std_logic_vector(tmp,10); --turn integer to vector
end process;
-------------------------------------------------------------------
Tx_combi_nextState: process(curState_tx, data_R)
begin

end process;
---------------------------------------------------------------------
seq_state: process (clk, reset)
begin
    if clk'event and clk='1' then
       if reset = '1' then  --reset is a synchronous signal and reset when high
           curState_rx <= INIT;
           curState_tx <= IDLE;             
       else
           curState_rx <= nextState_rx;
           curState_tx <= nextState_tx;
       end if;   
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
        rxdone <= done;
        start <= start_cmd;
        numWords_bcd <= numWords_bcd_array;
        seq_done <= seqDone;
        data_R <= dataReady;
    else
        data_rx <= data_rx;
        oe <= oe;
        fe <= fe;
        valid <= valid;
        done <= done;
        start_cmd <= start_cmd;
        numWords_bcd_array <= numWords_bcd_array;
        seq_done <= seq_done;
        data_R <= data_R;
    end if;
end process;
-------------------------------------------------------------------
combi_out: process(curState_rx)
begin
end process; -- combi_output
-------------------------------------------------------------------

end Behavioral;
