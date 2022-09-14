module sdram_controller(

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
    
    //sdram pin
    output              sdram_cke       ,
    output              sdram_csn       ,
    output              sdram_rasn      ,
    output              sdram_casn      ,
    output              sdram_wen       ,
    output  [12:0]      sdram_addr      ,
    output  [1:0]       sdram_bank      ,
    inout   [15:0]      sdram_dq        ,
    output  [1:0]       sdram_dqm       
);

//信号定义
    wire    [23:0]      m_address       ; 
    wire    [15:0]      m_wr_data       ; 
    wire                m_read          ; 
    wire                m_write         ; 
    wire    [8:0]       m_burst_size    ; 
    wire    [1:0]       m_byte_enable   ;
    wire    [15:0]      s_rd_dout       ; 
    wire                s_rd_dout_vld   ; 
    wire                s_rdy           ; 
    wire    [15:0]      sdram_dq_in     ;
    wire    [15:0]      sdram_dq_out    ;
    wire                sdram_dq_oe     ;

    assign sdram_dq = sdram_dq_oe?sdram_dq_out:16'hzzzz;
    assign sdram_dq_in = sdram_dq;

//模块例化    
    sdram_ctrl u_ctrl(
    /*input               */.clk             (clk           ),//100M
    /*input               */.clk_in          (clk_in        ),//50M
    /*input               */.clk_out         (clk_out       ),//50M
    /*input               */.rst_n           (rst_n         ),
    
    //数据输入
    /*input   [7:0]       */.din             (din           ),
    /*input               */.din_vld         (din_vld       ),

    //数据输出
    /*input               */.read_req        (read_req      ),//读数据请求
    /*output  [7:0]       */.dout            (dout          ),
    /*output              */.dout_vld        (dout_vld      ),
    /*input               */.busy            (busy          ),

    //sdram_intf
	/*output  [23:0]      */.m_address       (m_address     ),
	/*output  [15:0]      */.m_writedata     (m_wr_data     ),
	/*output              */.m_read          (m_read        ),
	/*output              */.m_write         (m_write       ),
    /*output  [8:0]       */.m_burst_size    (m_burst_size  ),
    /*output  [1:0]       */.m_byte_enable   (m_byte_enable ),
    /*input   [15:0]   	  */.m_readdata      (s_rd_dout     ),
    /*input           	  */.m_readdatavalid (s_rd_dout_vld ),
    /*input           	  */.m_rdy           (s_rdy         )
);
    sdram_intf u_intf(
    /*input           */.clk             (clk           ),
    /*input           */.rst_n           (rst_n         ),
    
    //master interface*/.
    /*input           */.s_wr_req        (m_write       ),
    /*input           */.s_rd_req        (m_read        ),
    /*input   [15:0]  */.s_wr_din        (m_wr_data     ),
    /*input   [1:0]   */.s_byte_enable   (m_byte_enable ),//字节使能 控制dqm
    /*input   [8:0]   */.s_burst_size    (m_burst_size  ),//突发长度
    /*input   [23:0]  */.s_address       (m_address     ),//写、读地址
    /*output          */.s_rdy           (s_rdy         ),
    /*output  [15:0]  */.s_rd_dout       (s_rd_dout     ),
    /*output          */.s_rd_dout_vld   (s_rd_dout_vld ),

    //sdram pin
    /*output          */.sdram_cke       (sdram_cke     ),
    /*output          */.sdram_csn       (sdram_csn     ),
    /*output          */.sdram_rasn      (sdram_rasn    ),
    /*output          */.sdram_casn      (sdram_casn    ),
    /*output          */.sdram_wen       (sdram_wen     ),
    /*output  [12:0]  */.sdram_addr      (sdram_addr    ),
    /*output  [1:0]   */.sdram_bank      (sdram_bank    ),
    /*input   [15:0]  */.sdram_dq_in     (sdram_dq_in   ),
    /*output  [15:0]  */.sdram_dq_out    (sdram_dq_out  ),
    /*output          */.sdram_dq_oe     (sdram_dq_oe   ),
    /*output  [1:0]   */.sdram_dqm       (sdram_dqm     )
);

endmodule 

