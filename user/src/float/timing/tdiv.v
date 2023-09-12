module tdiv #(
        parameter EXP = 5,
        parameter FRA = 10
    ) (
        input             aclk,
        input             aresetn,

        //S_AXIS_A
        input [EXP+FRA:0] s_axis_a_tdata,
        input             s_axis_a_tvalid,
        output            s_axis_a_tready,

        //S_AXIS_B
        input [EXP+FRA:0] s_axis_b_tdata,
        input             s_axis_b_tvalid,
        output            s_axis_b_tready,

        //M_AXIS_RESULT
        //m_axis_result_tdata: Output specifications, non-specified number output to 0
        output [EXP+FRA:0] m_axis_result_tdata,
        //the output is invalid
        output             m_axis_result_tvalid,
        //input            m_axis_result_tready,

        //Zero: flag[0]=1  Inf: flag[1] = 1  NaN: flag[2] = 1
        output [2:0]       flag
    );

    localparam SUB_NORMAL = 3'b001;
    localparam INFINITY   = 3'b010;
    localparam NORMAL     = 3'b100;

    wire 	         signA, signB;
    wire [EXP-1:0]	 expoA, expoB;
    wire [FRA:0]	 fracA, fracB;
    wire             M_unpack_A_tvalid;
    wire             M_unpack_B_tvalid;

    //disassemble for each part of the floating point number
    //One clock cycles are consumed
    unpack_sequential #(
        .EXP (EXP),
        .FRA (FRA))
    u_unpack_sequential(
        .aclk           (aclk),
        .aresetn        (aresetn),

        .inA            (s_axis_a_tdata),
        .S_A_tvalid     (s_axis_a_tvalid),

        .inB            (s_axis_b_tdata),
        .S_B_tvalid     (s_axis_b_tvalid),

        .signA          (signA),
        .expoA          (expoA),
        .fracA          (fracA),
        .M_A_tvalid     (M_unpack_A_tvalid),

        .signB          (signB),
        .expoB          (expoB),
        .fracB          (fracB),
        .M_B_tvalid     (M_unpack_B_tvalid)
    );//one

    reg                     r_sign;
    reg                     d_sign;
    reg                     sign;

    reg  signed [EXP:0]     r_iexpo;
    reg  signed [EXP-1:0]   d_iexpo;
    reg  signed [EXP-1:0]   iexpo;

    reg         [2*FRA+1:0] fraction;
    reg         [2*FRA+1:0] r_fracA;
    reg         [FRA:0]     r_fracB;

    reg         [FRA+1:0]   d_ifrac;
    reg         [FRA:0]     ifrac;

    reg         [2:0]       state;
    reg         [2:0]       d_state;

    reg                     r_normal_valid;
    reg                     normal_valid;

    /*second cycle*/
    //Exponential subtraction
    always @(posedge aclk or posedge aresetn) begin
        if(aresetn)begin
            r_sign         <= 1'b0;
            r_iexpo        <= 1'b0;
            r_fracA        <= 1'b0;
            r_fracB        <= 1'b0;
            r_normal_valid <= 1'b0;
        end
        else begin
            r_sign         <= signA ^ signB;
            r_iexpo        <= $signed({1'b0,expoA}) - $signed({1'b0,expoB});
            r_fracA        <= {fracA,{(FRA+1){1'b0}}};
            r_fracB        <= fracB;
            r_normal_valid <= M_unpack_A_tvalid & M_unpack_B_tvalid;
        end
    end

    //Status judgment
    always @(*) begin
        if(aresetn)begin
            state    <= NORMAL;
            fraction <= 1'b0;
        end
        else if($signed(r_iexpo) + 2**(EXP-1) < 1)begin
            state    <= SUB_NORMAL;
            fraction <= r_fracA >> (2 - $signed(r_iexpo) - 2**(EXP-1) + 1);
        end
        else if($signed(r_iexpo) >= 31)begin
            state    <= INFINITY;
            fraction <= 1'b0;
        end
        else begin
            state    <= NORMAL;
            fraction <= r_fracA;
        end
    end

    /*third cycle*/
    //Subtracting mantissa
    always @(posedge aclk) begin
        d_sign       <= r_sign;
        d_ifrac      <= fraction/r_fracB;
        d_state      <= state;
        normal_valid <= r_normal_valid;
        case(state)
            NORMAL:begin
                d_iexpo <= r_iexpo + 2**(EXP-1) - 1'b1;
            end
            SUB_NORMAL:begin
                d_iexpo <= 1'b0;
            end
            INFINITY:begin
                d_iexpo <= 2**(EXP-1) - 1'b1;
            end
            default:begin
                d_iexpo <= 1'b0;
            end
        endcase
    end

    always @(*) begin
        case(d_state)
            NORMAL:begin
                iexpo <= d_iexpo;
                if(d_ifrac[0])
                    ifrac <= d_ifrac[FRA+1:1] + 1'b1;
                else 
                    ifrac <= d_ifrac[FRA+1:1];
            end
            SUB_NORMAL:begin
                iexpo <= d_iexpo;
                if(d_ifrac[0])begin
                    if(d_ifrac[FRA])begin
                        ifrac <= d_ifrac[FRA:0] + 1'b1;
                    end
                    else begin
                        ifrac <= {~d_ifrac[FRA],d_ifrac[FRA-1:0]} + 1'b1;
                    end
                end
                else begin
                    if(d_ifrac[FRA])begin
                        ifrac <= d_ifrac[FRA:0];
                    end
                    else begin
                        ifrac <= {~d_ifrac[FRA],d_ifrac[FRA-1:0]};
                    end
                end
            end
            INFINITY:begin
                iexpo <= d_iexpo;
                ifrac <= {1'b1,d_ifrac[FRA:1]};
            end
            default:begin
                iexpo <= 1'b0;
                ifrac <= 1'b0;
            end
        endcase
    end

    //fourth cycle
    always @(posedge aclk) begin
        sign <= d_sign;
    end

    wire [FRA - 1 : 0] ofrac;
    wire [EXP - 1 : 0] oexpo;
    wire               M_normal_valid;

    normal_tmult #(
        .EXP (EXP),
        .FRA (FRA))
    u_normal_tmult(
        .aclk           (aclk),
        .aresetn        (aresetn),

        .iexpo          (iexpo),
        .ifrac          (ifrac),
        .S_tvalid       (normal_valid),

        .oexpo          (oexpo),
        .ofrac          (ofrac),
        .M_tvalid       (M_normal_valid)
    );

    cksp #(
        .EXP (EXP),
        .FRA (FRA))
    u_cksp(
        .expo	  (oexpo),
        .frac	  (ofrac),

        .flag 	  (flag)
    );

    pack #(
        .EXP 		( EXP 		),
        .FRA 		( FRA 		))
    u_pack(
        //ports
        .out  		( m_axis_result_tdata),
        .sign 		( sign 		         ),
        .expo 		( oexpo 	         ),
        .frac 		( ofrac 	         )
    );

    assign s_axis_a_tready      = s_axis_a_tvalid;
    assign s_axis_b_tready      = s_axis_b_tvalid;
    assign m_axis_result_tvalid = M_normal_valid;

endmodule