module top(

    input           clk         ,
    input           rst_n       ,
    input           key         ,//触发读
    input           uart_rxd    ,
    output          uart_txd    ,
    
    //sdram
    output          sdram_clk   ,
    output          sdram_cke   ,
    output          sdram_rasn  ,
    output          sdram_casn  ,
    output          sdram_csn   ,
    output          sdram_wen   ,
    output  [12:0]  sdram_addr  ,
    output  [1:0]   sdram_bank  ,
    inout   [15:0]  sdram_dq    ,
    output  [1:0]   sdram_dqm   
);

//信号定义

    wire            clk_100m        ;
    wire            clk_100m_s      ;
    wire            locked          ;
    wire            key_out         ;
    wire    [7:0]   rx_byte         ;
    wire            rx_byte_vld     ;
    wire    [7:0]   tx_byte         ;
    wire            tx_byte_vld     ;
    wire            tx_busy         ;

    assign sdram_clk = clk_100m_s;

//模块例化

    pll u_pll(
	.areset     (~rst_n     ),
	.inclk0     (clk        ),
	.c0         (clk_100m   ),
	.c1         (clk_100m_s ),
	.locked     (locked     )
    );
    
    key_debounce #(.KEY_W(1)) u_key(
	/*input					*/.clk		(clk        ),
	/*input					*/.rst_n	(rst_n      ),
	/*input	    [KEY_W-1:0]	*/.key_in 	(key        ),
	/*output	[KEY_W-1:0]	*/.key_out	(key_out    ) 
    );

    uart_rx u_rx(       //接收串行数据 串并转换
    /*input               */.clk     (clk           ),
    /*input               */.rst_n   (rst_n         ),
    /*input   [1:0]       */.baud_sel(2'd0          ),
    /*input               */.rx_din  (uart_rxd      ),
    /*output  [7:0]       */.rx_dout (rx_byte       ),
    /*output              */.rx_vld  (rx_byte_vld   ) 
    );

    sdram_controller u_controller(
    /*input               */.clk         (clk_100m   ),
    /*input               */.clk_in      (clk        ),
    /*input               */.clk_out     (clk        ),
    /*input               */.rst_n       (rst_n      ),
    
    //数据输入
    /*input   [7:0]       */.din         (rx_byte    ),
    /*input               */.din_vld     (rx_byte_vld),

    //数据输出
    /*input               */.read_req    (key_out    ),//读数据请求
    /*output  [7:0]       */.dout        (tx_byte    ),
    /*output              */.dout_vld    (tx_byte_vld),
    /*input               */.busy        (tx_busy    ),

    //sdram引脚
    /*output              */.sdram_cke   (sdram_cke  ),
    /*output              */.sdram_rasn  (sdram_rasn ),
    /*output              */.sdram_casn  (sdram_casn ),
    /*output              */.sdram_csn   (sdram_csn  ),
    /*output              */.sdram_wen   (sdram_wen  ),
    /*output  [12:0]      */.sdram_addr  (sdram_addr ),
    /*output  [1:0]       */.sdram_bank  (sdram_bank ),
    /*input   [15:0]      */.sdram_dq    (sdram_dq   ),
    /*output  [1:0]       */.sdram_dqm   (sdram_dqm  )
    );

    uart_tx u_tx(       //发送数据  并串转换
    /*input               */.clk     (clk           ),
    /*input               */.rst_n   (rst_n         ),
    /*input   [1:0]       */.baud_sel(2'd0          ),
    /*input   [7:0]       */.din     (tx_byte       ),
    /*input               */.din_vld (tx_byte_vld   ),
    /*output              */.tx_dout (uart_txd      ),
    /*output              */.tx_busy (tx_busy       ) //发送状态指示   
    );


endmodule 


