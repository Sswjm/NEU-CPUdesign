`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire data_sram_en,   // if load or store?
    output wire [3:0] data_sram_wen,  //all 0:load, all 1:store
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    //data correlation
    output wire [`EX_TO_MEM_WD-1:0] ex_to_id_bus,

    //stall 
    output wire stallreq_for_ex,

    output wire stall_en    //to id

    //output wire [3:0] load_judge
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    wire [31:0] hi_rdata, lo_rdata;
    wire hi_we, lo_we;
    wire [3:0] sel_move_dst;
    wire [3:0] div_mul_select;
    reg is_in_delayslot;
    wire is_lsa;
    wire [1:0] lsa_sa;

    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2,          // 31:0
        hi_we,
        lo_we,
        hi_rdata,
        lo_rdata,
        sel_move_dst,     //move instructions control
        div_mul_select,    //divide and multiple instructions control
        is_lsa,
        lsa_sa
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    wire [31:0] hi_wdata, lo_wdata;
    wire [31:0] lsa_result;

    //hilo part start
    /*assign hi_wdata = sel_move_dst[0] ? rf_rdata1 : 32'b0;    //rs --> hi
    assign lo_wdata = sel_move_dst[1] ? rf_rdata1 : 32'b0;    //rs --> lo*/

    //hilo part end

    //alu part
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op      ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result = sel_move_dst[2] ? hi_rdata    //hi --> rd
                    : sel_move_dst[3]  ? lo_rdata    //lo --> rd
                    : is_lsa ? lsa_result
                    : alu_result;

    //hilo part start
    assign hi_wdata = sel_move_dst[0] ? rf_rdata1  //rs --> hi
                    : (div_mul_select[0] | div_mul_select[1]) ? div_result[63:32]    //div
                    : (div_mul_select[2] | div_mul_select[3]) ? mul_result[63:32]    //mul
                    : hi_rdata;
    assign lo_wdata = sel_move_dst[1] ? rf_rdata1  //rs --> lo
                    : (div_mul_select[0] | div_mul_select[1]) ? div_result[31:0]    //div
                    : (div_mul_select[2] | div_mul_select[3]) ? mul_result[31:0]
                    : lo_rdata;    

    //hilo part end

    //load and store instructions
    //assign load_judge = data_ram_wen;   // transfer to mem to judge which kind of load is

    assign stall_en = data_ram_en 
                    & (data_ram_wen == 4'b0 | data_ram_wen == 4'b0001 | data_ram_wen == 4'b0010 
                        | data_ram_wen == 4'b0100 | data_ram_wen == 4'b0110);   
                    //tell "id" to stall if this instruction is a load instruction

    assign data_sram_en = data_ram_en;

    assign data_sram_wen = (data_ram_wen == 4'b1101 & alu_result[1:0] == 2'b00) ? 4'b0011  //sh
                    : (data_ram_wen == 4'b1101 & alu_result[1:0] == 2'b10) ? 4'b1100       //sh
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b00) ? 4'b0001       //sb
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b01) ? 4'b0010       //sb
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b10) ? 4'b0100       //sb
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b11) ? 4'b1000       //sb
                    : (data_ram_wen == 4'b1111) ? 4'b1111                                  //sw
                    : 4'b0;                                                                //loads


    assign data_sram_addr = alu_result;
    //assign data_sram_wdata = (data_ram_wen == 4'b1111) ? rf_rdata2 : 32'b0;
    assign data_sram_wdata = (data_ram_wen == 4'b1101 & alu_result[1:0] == 2'b00) ? {16'b0, rf_rdata2[15:0]}
                    : (data_ram_wen == 4'b1101 & alu_result[1:0] == 2'b10) ? {rf_rdata2[15:0], 16'b0}
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b00) ? {24'b0, rf_rdata2[7:0]}
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b01) ? {16'b0,rf_rdata2[7:0], 8'b0}
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b10) ? {8'b0, rf_rdata2[7:0], 16'b0}
                    : (data_ram_wen == 4'b1110 & alu_result[1:0] == 2'b11) ? {rf_rdata2[7:0], 24'b0}
                    : (data_ram_wen == 4'b1111) ? rf_rdata2
                    : 32'b0;

    //load and store instructions end

    // lsa part start
    assign lsa_result = (rf_rdata1 << (lsa_sa + 3'b001)) + rf_rdata2;
    

    // lsa part end

    assign ex_to_mem_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result,      // 31:0
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata,
        data_ram_wen
    };

    assign ex_to_id_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result,       // 31:0
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata,
        data_ram_wen
    };

    // MUL part
    /*wire [63:0] mul_result;
    wire inst_mult, inst_multu;
    wire mul_signed; // 有符号乘法标�??
    reg stallreq_for_mul;

    assign mul_signed = div_mul_select[2];   //inst_mult
    assign inst_mult = div_mul_select[2];
    assign inst_multu = div_mul_select[3];

    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (rf_rdata1      ), // 乘法源操作数1
        .inb        (rf_rdata2      ), // 乘法源操作数2
        .result     (mul_result     )  // 乘法结果 64bit
    );*/
    
    wire [63:0] mul_result;
    wire inst_mult, inst_multu;
    wire mul_ready_i;
    reg stallreq_for_mul;

    assign inst_mult = div_mul_select[2];
    assign inst_multu = div_mul_select[3];


    reg [31:0] mul_opdata1_o;
    reg [31:0] mul_opdata2_o;
    reg mul_start_o;
    reg signed_mul_o;

    mymul u_mul(
        .rst          (rst          ),
        .clk          (clk          ),
        .signed_mul_i (signed_mul_o ),
        .opdata1_i    (mul_opdata1_o    ),
        .opdata2_i    (mul_opdata2_o    ),
        .start_i      (mul_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (mul_result     ), // 除法结果 64bit
        .ready_o      (mul_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_mul = `NoStop;
            mul_opdata1_o = `ZeroWord;
            mul_opdata2_o = `ZeroWord;
            mul_start_o = `MulStop;
            signed_mul_o = 1'b0;
        end
        else begin
            stallreq_for_mul = `NoStop;
            mul_opdata1_o = `ZeroWord;
            mul_opdata2_o = `ZeroWord;
            mul_start_o = `MulStop;
            signed_mul_o = 1'b0;
            case ({inst_mult,inst_multu})
                2'b10:begin
                    if (mul_ready_i == `MulResultNotReady) begin
                        mul_opdata1_o = rf_rdata1;
                        mul_opdata2_o = rf_rdata2;
                        mul_start_o = `MulStart;
                        signed_mul_o = 1'b1;
                        stallreq_for_mul = `Stop;
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        mul_opdata1_o = rf_rdata1;
                        mul_opdata2_o = rf_rdata2;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b1;
                        stallreq_for_mul = `NoStop;
                    end
                    else begin
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                2'b01:begin
                    if (mul_ready_i == `MulResultNotReady) begin
                        mul_opdata1_o = rf_rdata1;
                        mul_opdata2_o = rf_rdata2;
                        mul_start_o = `MulStart;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `Stop;
                    end
                    else if (mul_ready_i == `MulResultReady) begin
                        mul_opdata1_o = rf_rdata1;
                        mul_opdata2_o = rf_rdata2;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                    else begin
                        mul_opdata1_o = `ZeroWord;
                        mul_opdata2_o = `ZeroWord;
                        mul_start_o = `MulStop;
                        signed_mul_o = 1'b0;
                        stallreq_for_mul = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;
    wire div_ready_i;
    reg stallreq_for_div;

    assign inst_div = div_mul_select[0];
    assign inst_divu = div_mul_select[1];

    assign stallreq_for_ex = stallreq_for_div | stallreq_for_mul;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;


    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result �?? div_result 可以直接使用

    
    
    
endmodule