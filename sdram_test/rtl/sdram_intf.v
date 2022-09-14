module sdram_intf(
    input           clk             ,
    input           rst_n           ,
    
    //master interface
    input           s_wr_req        ,
    input           s_rd_req        ,
    input   [15:0]  s_wr_din        ,
    input   [1:0]   s_byte_enable   ,//字节使能 控制dqm
    input   [8:0]   s_burst_size    ,//突发长度
    input   [23:0]  s_address       ,//写、读地址
    output          s_rdy           ,
    output  [15:0]  s_rd_dout       ,
    output          s_rd_dout_vld   ,

    //sdram pin
    output          sdram_cke       ,
    output          sdram_csn       ,
    output          sdram_rasn      ,
    output          sdram_casn      ,
    output          sdram_wen       ,
    output  [12:0]  sdram_addr      ,
    output  [1:0]   sdram_bank      ,
    input   [15:0]  sdram_dq_in     ,
    output  [15:0]  sdram_dq_out    ,
    output          sdram_dq_oe     ,
    output  [1:0]   sdram_dqm       
);

//状态机参数定义

    localparam  WAIT  = 9'b0_0000_0001,//上电等到200us
                PRECH = 9'b0_0000_0010,//预充电
                AREF  = 9'b0_0000_0100,//自动刷新
                MRS   = 9'b0_0000_1000,//模式寄存器设置
                IDLE  = 9'b0_0001_0000,//空闲
                ACTI  = 9'b0_0010_0000,//行激活
                WRITE = 9'b0_0100_0000,//列写
                RECV  = 9'b0_1000_0000,//写恢复
                READ  = 9'b1_0000_0000;//列读

//时间参数定义
    parameter   TIME_WAIT = 10_000  ,//上电等待200us
                TIME_PREC = 3       ,//预充电命令时间20ns
                TIME_RRC  = 7       ,//自动刷新命令时间70ns
                TIME_AREF = 780     ,//自动刷新时间间隔7.8us
                TIME_MRS  = 3       ,//模式寄存器设置命令时间2clk
                TIME_ACTI = 7       ,//行激活命令时间50ns
                TIME_RECV = 3       ;//写恢复时间2个周期

//命令参数定义 CMD = {sdram_csn,sdram_rasn,sdram_casn,sdram_wen}
    
    localparam  CMD_NOP   = 4'b0111,//空操作命令
                CMD_PRECH = 4'b0010,//预充电
                CMD_AREF  = 4'b0001,//自动刷新
                CMD_MRS   = 4'b0000,//模式寄存器设置
                CMD_ACTI  = 4'b0011,//行激活
                CMD_WRITE = 4'b0100,//列写
                CMD_READ  = 4'b0101;//列读

//信号定义
    
    reg     [8:0]       state_c         ;
    reg     [8:0]       state_n         ;

    reg     [13:0]      cnt             ;//状态计数器、突发计数器
    wire                add_cnt         ;
    wire                end_cnt         ;
    reg     [13:0]      xx              ;

    reg     [9:0]       cnt_ref         ;//刷新计数器 
    wire                add_cnt_ref     ;
    wire                end_cnt_ref     ;    
    
    reg                 init_flag       ;//初始化标志
    reg                 ref_flag        ;//刷新请求标志
    
    reg     [3:0]       cmd             ;
    reg     [12:0]      addr            ;
    reg     [1:0]       dqm             ;
    reg     [15:0]      rd_data         ;
    reg     [3:0]       rd_data_vld     ;
    reg     [15:0]      dq_out          ;
    reg                 dq_oe           ;
    reg                 rdy             ;

    wire                wait2prech      ; 
    wire                prech2aref      ; 
    wire                prech2idle      ; 
    wire                aref2mrs        ; 
    wire                aref2idle       ; 
    wire                mrs2idle        ; 
    wire                idle2aref       ; 
    wire                idle2acti       ; 
    wire                acti2write      ; 
    wire                acti2read       ; 
    wire                write2recv      ; 
    wire                recv2prech      ; 
    wire                read2prech      ; 

    wire    [43:0]      fifo_data       ; //{s_wr_req,s_rd_req,byte_en,bank,row,col,data}
    wire                fifo_rdreq      ; 
    wire                fifo_wrreq      ; 
    wire                fifo_empty      ; 
    wire                fifo_full       ; 
    wire    [43:0]      fifo_q          ; 
    wire    [4:0]       fifo_usedw      ; 

//状态机设计

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            state_c <= WAIT;
        end
        else begin
            state_c <= state_n;
        end
    end

    always  @(*)begin
        case(state_c)
            WAIT  :begin 
                if(wait2prech)
                    state_n = PRECH;
                else 
                    state_n = state_c;
            end   
            PRECH :begin 
                if(prech2aref)
                    state_n = AREF;
                else if(prech2idle)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end
            AREF  :begin 
                if(aref2mrs)
                    state_n = MRS;
                else if(aref2idle)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end
            MRS   :begin 
                if(mrs2idle)
                    state_n = IDLE;
                else 
                    state_n = state_c;
            end
            IDLE  :begin 
                if(idle2aref)
                    state_n = AREF;
                else if(idle2acti)
                    state_n = ACTI;
                else 
                    state_n = state_c;
            end
            ACTI  :begin 
                if(acti2write)
                    state_n = WRITE;
                else if(acti2read)
                    state_n = READ;
                else 
                    state_n = state_c;
            end
            WRITE :begin 
                if(write2recv)
                    state_n = RECV;
                else 
                    state_n = state_c;
            end
            RECV  :begin 
                if(recv2prech)
                    state_n = PRECH;
                else 
                    state_n = state_c;
            end
            READ  :begin 
                if(read2prech)
                    state_n = PRECH;
                else 
                    state_n = state_c;
            end
            default:state_n = WAIT;
        endcase 
    end

    assign wait2prech = state_c == WAIT  && (end_cnt);
    assign prech2aref = state_c == PRECH && (end_cnt && init_flag);
    assign prech2idle = state_c == PRECH && (end_cnt);
    assign aref2mrs   = state_c == AREF  && (end_cnt && init_flag);
    assign aref2idle  = state_c == AREF  && (end_cnt && ~init_flag);
    assign mrs2idle   = state_c == MRS   && (end_cnt);
    assign idle2aref  = state_c == IDLE  && (end_cnt_ref | ref_flag);
    assign idle2acti  = state_c == IDLE  && (~fifo_empty);
    assign acti2write = state_c == ACTI  && (end_cnt && fifo_q[43]);
    assign acti2read  = state_c == ACTI  && (end_cnt && fifo_q[42]);
    assign write2recv = state_c == WRITE && (end_cnt);
    assign recv2prech = state_c == RECV  && (end_cnt);
    assign read2prech = state_c == READ  && (end_cnt);

    //计数器
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt <= 0; 
        end
        else if(add_cnt) begin
            if(end_cnt)
                cnt <= 0; 
            else
                cnt <= cnt+1 ;
       end
    end
    assign add_cnt = (state_c != IDLE);
    assign end_cnt = add_cnt  && cnt == (xx)-1 ;

    always  @(*)begin
        if(state_c == WAIT)
            xx = TIME_WAIT;
        else if(state_c == PRECH)
            xx = TIME_PREC;
        else if(state_c == AREF)
            xx = TIME_RRC;
        else if(state_c == MRS)
            xx = TIME_MRS;
        else if(state_c == ACTI)
            xx = TIME_ACTI;
        else if(state_c == WRITE | state_c == READ)
            xx = s_burst_size;
        else //if(state_c == RECV)
            xx = TIME_RECV;
    end

    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt_ref <= 0; 
        end
        else if(add_cnt_ref) begin
            if(end_cnt_ref)
                cnt_ref <= 0; 
            else
                cnt_ref <= cnt_ref+1 ;
       end
    end
    assign add_cnt_ref = (init_flag == 1'b0);
    assign end_cnt_ref = add_cnt_ref  && cnt_ref == (TIME_AREF)-1 ;
    
//init_flag
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            init_flag <= 1'b1;
        end
        else if(mrs2idle)begin
            init_flag <= 1'b0;
        end
    end

//ref_flag
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ref_flag <= 1'b0;
        end
        else if(end_cnt_ref)begin
            ref_flag <= 1'b1;
        end
        else if(aref2idle)begin
            ref_flag <= 1'b0;
        end
    end

//输出寄存器
    
    //cmd
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            cmd <= CMD_NOP;
        end
        else if(wait2prech | recv2prech | read2prech)begin
            cmd <= CMD_PRECH;
        end
        else if(prech2aref | idle2aref)begin
            cmd <= CMD_AREF;
        end
        else if(aref2mrs)begin 
            cmd <= CMD_MRS;
        end 
        else if(idle2acti)begin 
            cmd <= CMD_ACTI;
        end 
        else if(state_n == WRITE)begin 
            cmd <= CMD_WRITE;
        end 
        else if(state_n == READ)begin 
            cmd <= CMD_READ;
        end     
        else begin 
            cmd <= CMD_NOP;
        end 
    end

    //addr
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
        end
        else if(aref2mrs)begin  //设置模式寄存器    //突发长度为1，连续突发
            addr <= {3'b000,1'b0,2'b00,3'b011,1'b0,3'b000}; 
        end 
        else if(idle2acti)begin
            addr <= fifo_q[25 +:13];//激活时给行地址
        end
        else if(acti2write | acti2read)begin
            addr <= {4'd0,fifo_q[16 +:9]};     //获得起始列地址
        end     
        else if(state_c == WRITE | state_c == READ)begin
            addr <= addr + 1;       //计算列地址 
        end 
        else if(recv2prech | read2prech | wait2prech)begin 
            addr <= 1'b1 << 10;     //全bank预充电
        end 
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dqm <= 2'b00;
        end
        else if(state_n == RECV)begin
            dqm <= 2'b11;
        end
        else begin
            dqm <= fifo_q[41:40];
        end
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rdy <= 1'b0;
        end
        else begin
            rdy <= ~init_flag && ~fifo_full;
        end
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rd_data <= 0;
            rd_data_vld <= 3'b000;
        end
        else begin
            rd_data <= sdram_dq_in;
            rd_data_vld <= {rd_data_vld[2:0],state_c == READ};
        end
    end

//FIFO例化
    buffer u_buffer(
	.aclr   (~rst_n     ),
	.clock  (clk        ),
	.data   (fifo_data  ),
	.rdreq  (fifo_rdreq ),
	.wrreq  (fifo_wrreq ),
	.empty  (fifo_empty ),
	.full   (fifo_full  ),
	.q      (fifo_q     ),
	.usedw  (fifo_usedw )
    );

    assign fifo_data = {s_wr_req,s_rd_req,s_byte_enable,s_address,s_wr_din};
    assign fifo_rdreq = (state_c == WRITE | state_c == READ) && ~fifo_empty;
    assign fifo_wrreq = ~fifo_full && (s_wr_req | s_rd_req);

//输出    
    assign sdram_dqm  = dqm;
    assign sdram_bank = fifo_q[39:38];
    assign sdram_addr = addr;
    assign sdram_cke = 1'b1;
    assign sdram_dq_out = fifo_q[15:0];
    assign sdram_dq_oe = state_c == WRITE; 
    assign {sdram_csn,sdram_rasn,sdram_casn,sdram_wen} = cmd;
    assign s_rdy = rdy;
    assign s_rd_dout = rd_data;
    assign s_rd_dout_vld = rd_data_vld[3];

endmodule 

