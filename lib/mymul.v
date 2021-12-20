`include"defines.vh"

module mymul(
    input wire rst,
    input wire clk, 
    input wire signed_mul_i,
    input wire[31:0] opdata1_i,				//被乘数
	input wire[31:0] opdata2_i,				//乘数
	input wire start_i,						//是否开始乘法运算
    input wire annul_i,                     //是否取消乘法运算
	output reg[63:0] result_o,				//乘法运算结果
	output reg ready_o						//乘法运算是否结束
);
    // four states, mul_free, mul_on, mul_end, mul_by_zero
    reg [31:0] temp_op1;
    reg [31:0] temp_op2;
    reg [63:0] multiplicand;   //被乘数 每次运算左移1位
    reg [31:0] multiplier;     //乘数   每次运算右移1位
    reg [63:0] product_temp;   //临时结果

    reg [5:0] cnt;      //if 32, mul stop
    reg [1:0] state;    //共有四个状态

    wire [63:0] partial_product; //部分积

    assign partial_product = multiplier[0] ? multiplicand : {`ZeroWord, `ZeroWord};   

    always @ (posedge clk) begin
        if (rst) begin
            state <= `MulFree;
            ready_o <= `MulResultNotReady;
            result_o <= {`ZeroWord, `ZeroWord};
        end else begin
            case (state)
                `MulFree: begin
                    if (start_i == `MulStart && annul_i == 1'b0) begin
                        if (opdata1_i == `ZeroWord || opdata2_i == `ZeroWord) begin   //任何操作数为0，都进入MUL_BY_ZERO状态
                            state <= `MulByZero;
                        end else begin
                            state <= `MulOn;
                            cnt <= 6'b000000;
                            if (signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin    //op1为负数，取补码
                                temp_op1 = ~opdata1_i + 1;
                            end else begin
                                temp_op1 = opdata1_i;
                            end
                            if (signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1) begin    //op2为负数，取补码
                                temp_op2 = ~opdata2_i + 1;
                            end else begin
                                temp_op2 = opdata2_i;
                            end
                            multiplicand <= {32'b0, temp_op1};
                            multiplier <= temp_op2;
                            product_temp <= {`ZeroWord, `ZeroWord};
                        end
                    end else begin
                        ready_o <= `MulResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end

                `MulByZero: begin
                    product_temp <= {`ZeroWord, `ZeroWord};    //有一个运算数为0，结果为0
                    state <= `MulEnd;
                end

                `MulOn: begin
                    if (annul_i == 1'b0) begin
                        if (cnt != 6'b100000) begin
                            multiplicand <= {multiplicand[62:0], 1'b0};        //被乘数左移
                            multiplier <= {1'b0, multiplier[31:1]};            //乘数右移
                            product_temp <= product_temp + partial_product;    //相加
                            cnt <= cnt + 1;
                        end else begin   //运算结束，如果原来操作数为一正一负，取补码
                            if ((signed_mul_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                                product_temp <= ~product_temp + 1;
                            end
                            state <= `MulEnd;
                            cnt <= 6'b000000;
                        end
                    end else begin
                        state <= `MulFree;
                    end
                end

                `MulEnd: begin
                    result_o <= product_temp;
                    ready_o <= `MulResultReady;
                    if (start_i == `MulStop) begin
                        state <= `MulFree;
                        ready_o <= `MulResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end


            endcase
        end
    end

endmodule

