`include "param.v"

module  uart_tx(       //发送数据  并串转换
    input               clk     ,
    input               rst_n   ,
    input   [1:0]       baud_sel,
    input   [7:0]       din     ,
    input               din_vld ,
    output              tx_dout ,
    output              tx_busy  //发送状态指示   
);

//信号定义
    reg     [12:0]      cnt0        ;//波特率计数器
    wire                add_cnt0    ;
    wire                end_cnt0    ;
    reg     [3:0]       cnt1        ;//bit计数器
    wire                add_cnt1    ;
    wire                end_cnt1    ;
    reg                 add_flag    ;
    
    reg     [9:0]       tx_data     ;

    reg     [12:0]      baud        ;//选择分频系数
    reg                 tx_bit      ;

//计数器

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt0 <= 0; 
        end
        else if(add_cnt0) begin
            if(end_cnt0)
                cnt0 <= 0; 
            else
                cnt0 <= cnt0+1 ;
       end
    end
    assign add_cnt0 = (add_flag);
    assign end_cnt0 = add_cnt0  && cnt0 == (baud)-1 ;

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt1 <= 0; 
        end
        else if(add_cnt1) begin
            if(end_cnt1)
                cnt1 <= 0; 
            else
                cnt1 <= cnt1+1 ;
       end
    end
    assign add_cnt1 = (end_cnt0);
    assign end_cnt1 = add_cnt1  && cnt1 == (10)-1;

//add_flag  计数器使能信号
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            add_flag <= 1'b0;
        end
        else if(din_vld)begin
            add_flag <= 1'b1;
        end
        else if(end_cnt1)begin 
            add_flag <= 1'b0;
        end
    end

    always  @(*)begin
        case(baud_sel)
            0:baud = `BAUD_RATE_115200;
            1:baud = `BAUD_RATE_57600;
            2:baud = `BAUD_RATE_38400;
            3:baud = `BAUD_RATE_9600;
            default:baud = `BAUD_RATE_115200;
        endcase 
    end

//输出
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_data <= 0;
        end
        else if(din_vld)begin   
            tx_data <= {1'b1,din,1'b0};
        end
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_bit <= 1'b1;
        end
        else if(add_cnt0 && cnt0 == 1-1)begin
            tx_bit <= tx_data[cnt1];
        end
    end

    assign tx_busy = din_vld | add_flag;
    assign tx_dout = tx_bit;

endmodule 

