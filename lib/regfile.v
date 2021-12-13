`include "defines.vh"
module regfile(
    input wire clk,
    input wire [4:0] raddr1,
    output wire [31:0] rdata1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata2,
    
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,

    input wire hi_we,
    input wire [31:0] hi_wdata,
    input wire lo_we,
    input wire [31:0] lo_wdata,

    output wire [31:0] hi_rdata,
    output wire [31:0] lo_rdata
);
    reg [31:0] reg_array [31:0];

    reg [31:0] reg_hi;
    reg [31:0] reg_lo;
    // write
    always @ (posedge clk) begin
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
        if (hi_we) begin
            reg_hi <= hi_wdata;
        end
        if (lo_we) begin
            reg_lo <= lo_wdata;
        end
    end

    // read out 1
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : reg_array[raddr1];

    // read out2
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : reg_array[raddr2];

    //read hi
    assign hi_rdata = reg_hi;
    assign lo_rdata = reg_lo;
    
endmodule