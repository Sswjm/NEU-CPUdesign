`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,  //read from memory

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,

    //data correlation
    output wire [`MEM_TO_WB_WD-1:0] mem_to_id_bus

    //input wire [3:0] load_judge
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;
    wire hi_we, lo_we;
    wire [31:0] hi_wdata, lo_wdata;
    wire [3:0] load_judge;

    assign {
        mem_pc,         // 75:44
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
        load_judge
    } =  ex_to_mem_bus_r;

    assign mem_result = (load_judge == 4'b0110 & ex_result[1:0] == 2'b00) ? {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]}  //lb
                    : (load_judge == 4'b0110 & ex_result[1:0] == 2'b01) ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]}  //lb
                    : (load_judge == 4'b0110 & ex_result[1:0] == 2'b10) ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} //lb
                    : (load_judge == 4'b0110 & ex_result[1:0] == 2'b11) ? {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} //lb
                    : (load_judge == 4'b0100 & ex_result[1:0] == 2'b00) ? {24'b0, data_sram_rdata[7:0]}                     //lbu
                    : (load_judge == 4'b0100 & ex_result[1:0] == 2'b01) ? {24'b0, data_sram_rdata[15:8]}                    //lbu
                    : (load_judge == 4'b0100 & ex_result[1:0] == 2'b10) ? {24'b0, data_sram_rdata[23:16]}                   //lbu
                    : (load_judge == 4'b0100 & ex_result[1:0] == 2'b11) ? {24'b0, data_sram_rdata[31:24]}                   //lbu
                    : (load_judge == 4'b0010 & ex_result[1:0] == 2'b00) ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]}  //lh
                    : (load_judge == 4'b0010 & ex_result[1:0] == 2'b10) ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} //lh
                    : (load_judge == 4'b0001 & ex_result[1:0] == 2'b00) ? {16'b0, data_sram_rdata[15:0]}                    //lhu
                    : (load_judge == 4'b0001 & ex_result[1:0] == 2'b10) ? {16'b0, data_sram_rdata[31:16]}                   //lhu
                    : data_sram_rdata;                                                                                  //lw
    
    assign rf_wdata = (sel_rf_res) ? mem_result : ex_result;

    assign mem_to_wb_bus = {
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata,    // 31:0
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata
    };

    assign mem_to_id_bus = {
        mem_pc,    //41:38
        rf_we,     //37
        rf_waddr,  //36:32
        rf_wdata,   //31:0
        hi_we,
        lo_we,
        hi_wdata,
        lo_wdata
    };


endmodule