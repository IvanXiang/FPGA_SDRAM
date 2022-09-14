`include"param.v"
module sdram_ctrl (
    input               clk             ,//100M
    input               clk_in          ,//50M
    input               clk_out         ,//50M
    input               rst_n           ,
    
    //数据输入
    input   [7:0]       din             ,
    input               din_vld         ,

    //数据输出
    input               read_req        ,//读数据请求
    output  [7:0]       dout            ,
    output              dout_vld        ,
    input               busy            ,

    //sdram_intf
	output  [23:0]      m_address       ,
	output  [15:0]      m_writedata     ,
	output              m_read          ,
	output              m_write         ,
    output  [8:0]       m_burst_size    ,
    output  [1:0]       m_byte_enable   ,
    input   [15:0]   	m_readdata      ,
    input           	m_readdatavalid ,
    input           	m_rdy      
);

//状态机参数定义

    localparam  IDLE  = 4'b0001,
                WRITE = 4'b0010,//突发写
                READ  = 4'b0100,//突发读
                DONE  = 4'b1000;
//信号定义

    reg     [3:0]   state_c     ;
    reg     [3:0]   state_n     ;

    reg     [8:0]   cnt         ;//突发计数器
    wire            add_cnt     ;
    wire            end_cnt     ;
    
    reg     [23:0]  wr_addr     ;//写地址 bank + row + col 
    wire            add_wr_addr ;
    wire            end_wr_addr ;
    reg     [23:0]  rd_addr     ;//读地址
    wire            add_rd_addr ;
    wire            end_rd_addr ;

    reg     [7:0]   tx_data     ;
    reg             tx_data_vld ;

    wire            wrfifo_rd   ;
    wire            wrfifo_wr   ;
    wire    [7:0]   wrfifo_q    ;
    wire            wrfifo_empt ;
    wire    [5:0]   wrfifo_used ;
    wire            wrfifo_full ;
    
    wire    [7:0]   rdfifo_data ;
    wire            rdfifo_rd   ; 
    wire            rdfifo_wr   ;   
    wire    [7:0]   rdfifo_q    ;   
    wire            rdfifo_empt ;   
    wire            rdfifo_full ;   

    wire            idle2write  ; 
    wire            idle2read   ; 
    wire            write2done  ; 
    wire            read2done   ; 
    wire            done2idle   ; 

//状态机设计    

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            state_c <= IDLE ;
        end
        else begin
            state_c <= state_n;
       end
    end
    
    always @(*) begin 
        case(state_c)  
            IDLE :begin
                if(idle2write)
                    state_n = WRITE ;
                else if(idle2read)
                    state_n = READ ;
                else 
                    state_n = state_c ;
            end
            WRITE :begin
                if(write2done)
                    state_n = DONE ;
                else 
                    state_n = state_c ;
            end
            READ :begin
                if(read2done)
                    state_n = DONE ;
                else 
                    state_n = state_c ;
            end
            DONE :begin
                if(done2idle)
                    state_n = IDLE ;
                else 
                    state_n = state_c ;
            end
            default : state_n = IDLE ;
        endcase
    end
    
    assign idle2write = state_c==IDLE  && (wrfifo_used >= `BURST_LEN);
    assign idle2read  = state_c==IDLE  && (read_req);
    assign write2done = state_c==WRITE && (end_cnt);
    assign read2done  = state_c==READ  && (end_cnt);
    assign done2idle  = state_c==DONE  && (1'b1);

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt <= 0;
        end
        else if(add_cnt)begin
            if(end_cnt)
                cnt <= 0;
            else
                cnt <= cnt + 1;
        end
    end

    assign add_cnt = (state_c == WRITE | state_c == READ) & m_rdy;       
    assign end_cnt = add_cnt && cnt == `BURST_LEN-1;   

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            wr_addr <= 0; 
        end
        else if(add_wr_addr) begin
            if(end_wr_addr)
                wr_addr <= 0; 
            else
                wr_addr <= wr_addr+`BURST_LEN;
       end
    end
    assign add_wr_addr = write2done;
    assign end_wr_addr = add_wr_addr && wr_addr == (`BURST_MAX-`BURST_LEN);

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            rd_addr <= 0; 
        end
        else if(add_rd_addr) begin
            if(end_rd_addr)
                rd_addr <= 0; 
            else
                rd_addr <= rd_addr+`BURST_LEN;
       end
    end
    assign add_rd_addr = read2done;
    assign end_rd_addr = add_rd_addr && rd_addr == (`BURST_MAX-`BURST_LEN);

    //tx_data_vld
    always  @(posedge clk_out or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_data_vld <= 0;
        end
        else begin
            tx_data_vld <= rdfifo_rd;
        end
    end

    always  @(posedge clk_out or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_data <= 0;
        end
        else begin
            tx_data <= rdfifo_q;
        end
    end

//FIFO例化

    wrfifo u_wrfifo(
	.aclr   (~rst_n     ),
	.data   (din        ),
	.rdclk  (clk        ),
	.rdreq  (wrfifo_rd  ),
	.wrclk  (clk_in     ),
	.wrreq  (wrfifo_wr  ),
	.q      (wrfifo_q   ),
	.rdempty(wrfifo_empt),
	.rdusedw(wrfifo_used),
	.wrfull (wrfifo_full)
    );

    assign wrfifo_wr = din_vld & ~wrfifo_full;
    assign wrfifo_rd = state_c == WRITE & m_rdy & ~wrfifo_empt; 

    rdfifo u_rdfifo(
	.aclr   (~rst_n         ),
	.data   (rdfifo_data    ),
	.rdclk  (clk_out        ),
	.rdreq  (rdfifo_rd      ),
	.wrclk  (clk            ),
	.wrreq  (rdfifo_wr      ),
	.q      (rdfifo_q       ),
	.rdempty(rdfifo_empt    ),
	.wrfull (rdfifo_full    )
    );
    
    assign rdfifo_data = m_readdata[7:0];
    assign rdfifo_wr = m_readdatavalid & ~rdfifo_full;
    assign rdfifo_rd = ~rdfifo_empt & ~busy;

//输出
    assign dout          = tx_data; 
    assign dout_vld      = tx_data_vld; 
    assign m_address   = {{24{state_c == WRITE}} & {wr_addr}} 
                       | {{24{state_c == READ}}  & {rd_addr}}; 
    assign m_burst_size = `BURST_LEN;
    assign m_byte_enable = 2'b00;
	assign m_writedata = {2{wrfifo_q}}; 
	assign m_read    = state_c == READ; 
	assign m_write   = state_c == WRITE;


 endmodule 


