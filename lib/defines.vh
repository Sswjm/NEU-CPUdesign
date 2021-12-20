`define IF_TO_ID_WD 33
//`define ID_TO_EX_WD 159
`define ID_TO_EX_WD 236    //add hi lo  lsa
//`define EX_TO_MEM_WD 76
`define EX_TO_MEM_WD 146  //add hi lo,load_judge
//`define MEM_TO_WB_WD 70
`define MEM_TO_WB_WD 136  //add hi lo
`define BR_WD 33
`define DATA_SRAM_WD 69
//`define WB_TO_RF_WD 38
`define WB_TO_RF_WD 104  //add hi lo

`define StallBus 6
`define NoStop 1'b0
`define Stop 1'b1

// 2021-11-29 add
`define ZeroWord 32'b0


//除法div
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0

//乘法mul
`define MulFree 2'b00
`define MulByZero 2'b01
`define MulOn   2'b10
`define MulEnd  2'b11
`define MulResultReady    1'b1
`define MulResultNotReady 1'b0
`define MulStart 1'b1
`define MulStop  1'b0
// 2021-11-29 add