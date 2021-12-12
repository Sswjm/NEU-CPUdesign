`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,   //stall

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus, 

    //data correlation
    input wire [`EX_TO_MEM_WD-1:0] ex_to_id_bus,  //ex-->id

    input wire [`MEM_TO_WB_WD-1:0] mem_to_id_bus,  //mem-->id

    input wire [`WB_TO_RF_WD-1:0] wb_to_id_bus,  //wb-->id

    input wire stall_en
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    reg if_id_stop;
    //reg [31:0] stall_inst;

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            if_id_stop <= 1'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            //stall_inst <= inst_sram_rdata;
            if_id_stop <= 1'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            if_id_stop <= 1'b0;
        end
        else if(stall[2] == `Stop) begin
            if_id_stop <= 1'b1;
        end
    end
    
    //assign inst = if_id_stop ? 32'b0 : inst_sram_rdata;
    assign inst = if_id_stop ? inst : inst_sram_rdata;
    //assign inst = (stall[2] == `Stop) ? inst : inst_sram_rdata;

    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    // instructions' declaration part start
    wire inst_ori, inst_lui , inst_addiu;
    wire inst_beq, inst_subu, inst_addu;
    wire inst_jal, inst_jr  , inst_sll;
    wire inst_or , inst_lw  , inst_xor;
    wire inst_sltu, inst_bne;
    // end

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_subu    = op_d[6'b00_0000] & func_d[6'b10_0011];
    assign inst_addu    = op_d[6'b00_0000] & func_d[6'b10_0001];
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_jr      = op_d[6'b00_0000] & func_d[6'b00_1000];
    assign inst_sll     = op_d[6'b00_0000] & func_d[6'b00_0000];
    assign inst_or      = op_d[6'b00_0000] & func_d[6'b10_0101];
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_xor     = op_d[6'b00_0000] & func_d[6'b10_0110];
    assign inst_sltu    = op_d[6'b00_0000] & func_d[6'b10_1011];
    assign inst_bne     = op_d[6'b00_0101];

    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu | inst_or | inst_lw | inst_xor | inst_sltu;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;



    assign op_add = inst_addiu | inst_addu | inst_jal | inst_lw;
    assign op_sub = inst_subu;
    assign op_slt = 1'b0;
    assign op_sltu = inst_sltu;
    assign op_and = 1'b0;
    assign op_nor = 1'b0;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor;
    assign op_sll = inst_sll;
    assign op_srl = 1'b0;
    assign op_sra = 1'b0;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_lw;   //0:store, 1:load

    // write enable
    //assign data_ram_wen = 1'b0;
    assign data_ram_wen = inst_lw ? 4'b0 : 4'b1;    //4'b0: load  4'b1: store



    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_addu | inst_jal | inst_sll
                    | inst_or | inst_lw | inst_xor | inst_sltu;



    // store in [rd]
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = inst_lw;
    

    //stall part start
    assign stallreq = ((stall_en) & ((rs == forwarding_ex_rf_waddr) | (rt == forwarding_ex_rf_waddr))) ? `Stop
                    : `NoStop;

    //end

    //data correlation start
    // we just use six of these variables, maybe after we will use the others
    wire [31:0] forwarding_ex_pc;
    wire forwarding_data_ram_en;
    wire [3:0] forwarding_data_ram_wen;
    wire forwarding_sel_rf_res;
    wire forwarding_ex_rf_we;             //main use
    wire [4:0] forwarding_ex_rf_waddr;    //main use
    wire [31:0] forwarding_ex_result;     //main use

    wire [31:0] forwarding_mem_pc;
    wire forwarding_mem_rf_we;                //main use
    wire [4:0] forwarding_mem_rf_waddr;   //main use
    wire [31:0] forwarding_mem_rf_wdata;  //main use

    
    wire [31:0] selected_rdata1, selected_rdata2;

    assign {
        forwarding_ex_pc,          // 75:44
        forwarding_data_ram_en,    // 43
        forwarding_data_ram_wen,   // 42:39
        forwarding_sel_rf_res,     // 38
        forwarding_ex_rf_we,          // 37
        forwarding_ex_rf_waddr,       // 36:32
        forwarding_ex_result       // 31:0
    } = ex_to_id_bus;

    assign {
        forwarding_mem_pc,    //41:38
        forwarding_mem_rf_we,     //37
        forwarding_mem_rf_waddr,  //36:32
        forwarding_mem_rf_wdata   //31:0
    } = mem_to_id_bus;


    assign selected_rdata1 = (forwarding_ex_rf_we & (forwarding_ex_rf_waddr == rs)) ? forwarding_ex_result
                            :(forwarding_mem_rf_we & (forwarding_mem_rf_waddr == rs)) ? forwarding_mem_rf_wdata
                            :(wb_rf_we & (wb_rf_waddr == rs)) ? wb_rf_wdata
                            :rdata1;

    assign selected_rdata2 = (forwarding_ex_rf_we & (forwarding_ex_rf_waddr == rt)) ? forwarding_ex_result
                            :(forwarding_mem_rf_we & (forwarding_mem_rf_waddr == rt)) ? forwarding_mem_rf_wdata
                            :(wb_rf_we & (wb_rf_waddr == rt)) ? wb_rf_wdata
                            :rdata2;
    
    //data correlation end

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        selected_rdata1,         // 63:32
        selected_rdata2          // 31:0
    };


    //branch

    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_neq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;
   
    assign rs_eq_rt = (selected_rdata1 == selected_rdata2);
    assign rs_neq_rt = (selected_rdata1 != selected_rdata2);

    assign br_e = inst_beq & rs_eq_rt | inst_jal | inst_jr | inst_bne & rs_neq_rt;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}}, inst[15:0], 2'b0})
                    : inst_jal ? ({pc_plus_4[31:28], inst[25:0], 2'b0})
                    : inst_jr ? selected_rdata1 
                    : inst_bne ? (pc_plus_4 + {{14{inst[15]}}, inst[15:0], 2'b0})
                    : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule