module tdiv_tb();

parameter EXP = 5;
parameter FRA = 10;
parameter MAIN_FRE   = 100; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst = 0;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 1;
end

// outports wire
reg     [EXP+FRA:0] s_axis_a_tdata;
reg     [EXP+FRA:0] s_axis_b_tdata;

reg					s_axis_a_tvalid;
reg					s_axis_b_tvalid;

reg                 m_axis_tready = 1'b1;

wire             	s_axis_a_tready;
wire             	s_axis_b_tready;
wire [EXP+FRA:0] 	m_axis_tdata;
wire             	m_axis_tvalid;

reg  [2:0]          a_addr;
reg  [2:0]          b_addr;

always @(*) begin
    case(a_addr)
        0:begin
            //result: 2.85 16'h41B3
            s_axis_a_tdata  <= 16'h388f; //0.57
            //s_axis_b_tdata  <= 16'h3266; //0.2
        end
        1:begin
            //result: 1.45E-5 16'h00f3
            s_axis_a_tdata  <= 16'h0cc0; //2.9E-4
            //s_axis_b_tdata  <= 16'h4d00; //20
        end
        2:begin
            //result: 2.5E-6 16'h002A
            s_axis_a_tdata  <= 16'h01a3; //2.5E-5
            //s_axis_b_tdata  <= 16'h4900; //10
        end
        3:begin
            //result:56 16'h5300
            s_axis_a_tdata  <= 16'h03ac; //5.6E-5
            //s_axis_b_tdata  <= 16'h0011; //1E-5
        end
        4:begin
            //result: 28 16'h4f00
            s_axis_a_tdata  <= 16'h1096; //5.6E-4
            //s_axis_b_tdata  <= 16'h0150; //2E-5
        end
        default:begin
            s_axis_a_tdata  <= 16'h388f; //0.57
            //s_axis_b_tdata  <= 16'h3266; //0.2
        end
    endcase
end

always @(*) begin
    case(b_addr)
        0:begin
            //result: 2.85 16'h41B3
            //s_axis_a_tdata  <= 16'h388f; //0.57
            s_axis_b_tdata  <= 16'h3266; //0.2
        end
        1:begin
            //result: 1.45E-5 16'h00f3
            //s_axis_a_tdata  <= 16'h0cc0; //2.9E-4
            s_axis_b_tdata  <= 16'h4d00; //20
        end
        2:begin
            //result: 2.5E-6 16'h002A
            //s_axis_a_tdata  <= 16'h01a3; //2.5E-5
            s_axis_b_tdata  <= 16'h4900; //10
        end
        3:begin
            //result:56 16'h5300
            //s_axis_a_tdata  <= 16'h03ac; //5.6E-5
            s_axis_b_tdata  <= 16'h0011; //1E-5
        end
        4:begin
            //result: 28 16'h4f00
            //s_axis_a_tdata  <= 16'h1096; //5.6E-4
            s_axis_b_tdata  <= 16'h0150; //2E-5
        end
        default:begin
            //s_axis_a_tdata  <= 16'h388f; //0.57
            s_axis_b_tdata  <= 16'h3266; //0.2
        end
    endcase
end

always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        a_addr <= 0;
    end
    else begin
        if(s_axis_a_tready)begin
            if(a_addr == 4)
                a_addr <= 0;
            else 
                a_addr <= a_addr + 1;
        end
        else begin
            a_addr          <= a_addr;
        end
    end
end

always @(posedge sys_clk) begin
    if(sys_rst == 1'b0)begin
        b_addr <= 0;
    end
    else begin
        if(s_axis_b_tready)begin
            if(b_addr == 4)
                b_addr <= 0;
            else 
                b_addr <= b_addr + 1;
        end
        else begin
            b_addr          <= b_addr;
        end
    end
end

always @(*) begin
    if(sys_rst == 1'b0)begin
        s_axis_a_tvalid <= 1'b0;
        s_axis_b_tvalid <= 1'b0;
    end
    else begin
        s_axis_a_tvalid <= s_axis_a_tready;
        s_axis_b_tvalid <= s_axis_b_tready;
    end
end

tdiv #(
    .EXP (EXP),
    .FRA (FRA)
)
u_tdiv(
	.aclk            	( sys_clk          ),
	.aresetn         	( sys_rst          ),
	
    .s_axis_a_tdata  	( s_axis_a_tdata   ),
	.s_axis_a_tvalid 	( s_axis_a_tvalid  ),
	.s_axis_a_tready 	( s_axis_a_tready  ),
	
    .s_axis_b_tdata  	( s_axis_b_tdata   ),
	.s_axis_b_tvalid 	( s_axis_b_tvalid  ),
	.s_axis_b_tready 	( s_axis_b_tready  ),
	
    .m_axis_tdata    	( m_axis_tdata     ),
	.m_axis_tready   	( m_axis_tready    ),
	.m_axis_tvalid   	( m_axis_tvalid    )
);

endmodule  //TOP

