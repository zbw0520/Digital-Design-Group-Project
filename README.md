# Digital-Design-Group-Project
### How to use github and git?
you can get some help from the link below:  
* [git](https://www.youtube.com/watch?v=nhNq2kIvi9s)  
* [github](https://www.youtube.com/watch?v=nhNq2kIvi9s)  

they are all quite easy to learn

### In the git and github we can share all the code and changes we made to improve efficiency.


# Pay attention to the following issues when coding
### 1. ALWAYS ABIDE BY "ONE VARIABLE ONE PROCESS" PRINCIPLE!!!! YOU CAN ONLY ASSIGN ONE VARIABLE IN ONE PROCESS EXCEPT FOR ARRAYS!!!! LATCHES CAN BE AVOID BY DOING SO. IF UNWANTED LATCHES EXISTS, GREAT PROSSIBILITY WILL BE THAT OUR CODES WON'T WORK WHEN WE IMPLEMENT THE CODE INTO FPGAS.(apply to all two files i.e. cmdProc.vhd and dataConsumer.vhd)
### 2. Omit oe signal in the code because oe never reset to 0 in RX_CTRL file, which has been shown is a bug.(apply to cmd_Proc only)
### 3. Try to do simulate in vivado which is more efficient and more dedicated and some libraries we are using only compatible with vivado.(apply to all two files)
### 4. Use start signal in cmdProc.vhd file to control the the rate of dataConsumer module's providing data. (apply to cmd_Proc only)
### 5. Try to use different files to write the module we are coding. E.g. we can use file A to implement state machine 1 and file B to implement state machine 2 and another file for the top port definition. There is 2 benefits of doing this. One is that we can achieve higher synthesis speed to speed up our developing process. The other one is that we can demonstrate our project management skills and achieve better marks. (apply to both files)


# Progress report
2/3/2020
Axxx command control flow has been done and simulation is successful!

3/3/2020
P command control flow has been done and simulation is successful!

3/3/2020
All command control flow has been done and cmdProc.vhd behavioural simulation turns out to be successful! cmdProc.vhd completed.

6/3/2020
The bit stream file has been generated and cmdProc.vhd can be synthesized and implemented.

8/3/2020
In previous cmdProc.vhd file, bugs are found such as cannot output correctly when input a001 and when input is axxx, output is xxx-1. These bugs have been fixed. However, when trying to generate bitstream file, I found there is some problems on constraints. Thus, I add some code to the .xdc file to fix the lack of constraints and also suppress some unnecessary errors. 

9/3/2020
In previous cmdProc.vhd file, axexx command can not be intepreted correctly. This has been fixed in this version. Change some of the code in order to avoid combinatorial loops. Plus, a new feature that output newline after sequence is being output has been added.

9/3/2020
Two files has been tested together. Bitstream file has been generated and it turns out to be working well. In dataConsume.vhd file we still need to develop the "P command" code and "L command" code for complete function.

17/3/2020
upload full function with echoing.

##License and copyright
© Bowen Zhang and Weifeng Du

License under the [MIT License](License)
