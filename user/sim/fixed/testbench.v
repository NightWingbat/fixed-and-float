module testbench();

parameter SYMBOL_A = "signed";
parameter SYMBOL_B = "signed";
parameter WIDTH_A  = 16;
parameter WIDTH_B  = 16;
parameter MAIN_FRE   = 100; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst = 0;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 1;
end

//Instance 
// outports wire
reg   [WIDTH_A - 1 : 0]     s_axis_a_tdata;
reg                         s_axis_a_tvalid;
reg   [WIDTH_B - 1 : 0]     s_axis_b_tdata;
reg                         s_axis_b_tvalid;
reg                         m_axis_tready;

wire                       	s_axis_a_tready;
wire                       	s_axis_b_tready;
wire [WIDTH_A+WIDTH_B-1:0] 	m_axis_tdata;
wire                       	m_axis_tvalid;

initial begin
        s_axis_a_tdata  = 0;
        s_axis_b_tdata  = 0;
        s_axis_a_tvalid = 1'b0;
        s_axis_b_tvalid = 1'b0;
        m_axis_tready   = 1'b0;
		#100
		s_axis_a_tvalid = 1'b1;
        s_axis_b_tvalid = 1'b1;
        m_axis_tready   = 1'b1;
        s_axis_a_tdata  = 15;
        s_axis_b_tdata  = 3;
        #100
        s_axis_a_tvalid = 1'b1;
        s_axis_b_tvalid = 1'b1;
        s_axis_a_tdata  = 27;
        s_axis_b_tdata  = 6;
        #100
        s_axis_a_tvalid = 1'b1;
        s_axis_b_tvalid = 1'b1;
        s_axis_a_tdata  = 53;
        s_axis_b_tdata  = 5;
        #100
        s_axis_a_tvalid = 1'b1;
        s_axis_b_tvalid = 1'b1;
        s_axis_a_tdata  = 13;
        s_axis_b_tdata  = 4;
        #100
        s_axis_a_tvalid = 1'b1;
        s_axis_b_tvalid = 1'b1;
        s_axis_a_tdata  = 37;
        s_axis_b_tdata  = 9;
    end

div u_div(
	.aclk            	( sys_clk          ),
	.aresetn         	( sys_rst          ),
	
    .s_axis_a_tdata  	( s_axis_a_tdata   ),
	.s_axis_a_tvalid 	( s_axis_a_tvalid  ),
	.s_axis_a_tready 	( s_axis_a_tready  ),
	
    .s_axis_b_tdata  	( s_axis_b_tdata   ),
	.s_axis_b_tvalid 	( s_axis_b_tvalid  ),
	.s_axis_b_tready 	( s_axis_b_tready  ),
	
    .m_axis_tdata    	( m_axis_tdata     ),
	.m_axis_tvalid   	( m_axis_tvalid    ),
	.m_axis_tready   	( m_axis_tready    )
);

endmodule  //TOP
