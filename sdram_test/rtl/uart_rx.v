`include "param.v"

module uart_rx (       //接收串行数据 串并转换
    input               clk     ,
    input               rst_n   ,
    input   [1:0]       baud_sel,
    input               rx_din  ,
    output  [7:0]       rx_dout ,
    output              rx_vld   
);

//定义信号
    reg     [12:0]      cnt0        ;//波特率计数器
    wire                add_cnt0    ;
    wire                end_cnt0    ;
    reg     [3:0]       cnt1        ;//bit计数器
    wire                add_cnt1    ;
    wire                end_cnt1    ;
    reg                 add_flag    ;
    
    reg     [12:0]      baud        ;//选择分频系数

    reg     [2:0]       rx_din_r    ;//同步、打拍寄存器
    wire                n_edge      ;//下降沿检测

    reg     [9:0] rx_data           ;//采样数据寄存器

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
    assign end_cnt1 = add_cnt1  && (cnt1 == (9-1) || rx_data[0]);

//add_flag  计数器使能信号
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            add_flag <= 1'b0;
        end
        else if(n_edge)begin
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

//下降沿检测  同步打拍
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rx_din_r <= 3'b111;
        end
        else begin
            rx_din_r <= {rx_din_r[1:0],rx_din};
            //rx_din_r[0] <= rx_din;      //同步
            //rx_din_r[1] <= rx_din_r[0]; //打拍
            //rx_din_r[2] <= rx_din_r[1]; //打拍
        end
    end

    assign n_edge = rx_din_r[2] & ~rx_din_r[1];

//采样数据
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rx_data <= 0;
        end
        else if(add_flag && cnt0 == (baud >> 1))begin
            //rx_data <= {rx_din,rx_data[`DATA_W:1]};//右移
            rx_data[cnt1] <= rx_din;
        end
    end

//输出

    assign rx_dout = rx_data[8:1];
    assign rx_vld  = end_cnt0 & cnt1 == (9)-1 & ~rx_data[0];

endmodule 

