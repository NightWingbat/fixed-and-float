module mult_tb();

parameter EXP = 5;
parameter FRA = 11 - 1;
parameter MAIN_FRE   = 100; //unit MHz
reg                   sys_clk = 0;
reg                   sys_rst = 1;

always begin
    #(500/MAIN_FRE) sys_clk = ~sys_clk;
end

always begin
    #50 sys_rst = 0;
end

//Instance 
reg              valid;
reg  [EXP+FRA:0] A;
reg  [EXP+FRA:0] B;
wire [EXP+FRA:0] Y;
wire [2:0]	     flag;

initial begin
    A     = 16'h2e66;
    B     = 16'h2e66;
    valid = 1'b0;
    #100
    valid = 1'b1;
end

cmult #(
	.EXP 		( EXP 		),
	.FRA 		( FRA 		))
u_nmult(
	//ports
    .aresetn    ( sys_rst   ),
    .valid      ( valid     ),
	.A    		( A    		),
	.B    		( B    		),
	.Y    		( Y    		),
	.flag 		( flag 		)
);

endmodule  //TOP
