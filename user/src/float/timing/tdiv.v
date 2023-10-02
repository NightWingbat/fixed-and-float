module tdiv #(
    parameter EXP = 5,
    parameter FRA = 10
) (
    input                   aclk,
    input                   aresetn,

    input   [EXP+FRA:0]     s_axis_a_tdata,
    input                   s_axis_a_tvalid,
    output  reg             s_axis_a_tready,

    input   [EXP+FRA:0]     s_axis_b_tdata,
    input                   s_axis_b_tvalid,
    output  reg             s_axis_b_tready,

    output  reg [EXP+FRA:0] m_axis_tdata,
    input                   m_axis_tready,
    output                  m_axis_tvalid
    
);

localparam  GET_A         = 4'd0,
            GET_B         = 4'd1,
            UNPACK        = 4'd2,
            SPECIAL_CASES = 4'd3,
            NORMALISE_A   = 4'd4,
            NORMALISE_B   = 4'd5,
            DIVIDE_0      = 4'd6,
            DIVIDE_1      = 4'd7,
            DIVIDE_2      = 4'd8,
            DIVIDE_3      = 4'd9,
            NORMALISE_1   = 4'd10,
            NORMALISE_2   = 4'd11,
            ROUND         = 4'd12,
            PACK          = 4'd13,
            PUT_Z         = 4'd14;

reg       [EXP+FRA:0] a, b, z;
reg                   a_s, b_s, z_s;
reg       [EXP+1:0]   a_e, b_e, z_e;
reg       [FRA:0]     a_m, b_m, z_m;

reg                   guard, round_bit, sticky;
reg       [2*FRA+4:0] quotient, divisor, dividend, remainder;
reg       [5:0]       count;

reg       [EXP+FRA:0] result;
reg                   ovalid;

reg       [3:0]       state_now,state_next;

always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        state_now <= GET_A;
    end
    else begin
        state_now <= state_next;
    end
end

always @(*) begin
    case(state_now)
        GET_A:begin
            if(s_axis_a_tvalid && s_axis_a_tready)
                state_next  <= GET_B;
            else 
                state_next  <= GET_A; 
        end
        GET_B:begin
            if(s_axis_b_tvalid && s_axis_b_tready)
                state_next  <= UNPACK;
            else 
                state_next  <= GET_B;
        end
        UNPACK:begin
            state_next  <= SPECIAL_CASES;
        end
        SPECIAL_CASES:begin
            //if a is NaN or b is NaN return NaN 
            if ((a_e == 2**(EXP-1) && a_m != 0) || (b_e == 2**(EXP-1) && b_m != 0)) begin
                state_next <= PUT_Z; 
            end 
            //if a is inf and b is inf return NaN
            else if ((a_e == 2**(EXP-1)) && (b_e == 2**(EXP-1))) begin
                state_next <= PUT_Z;
            end 
            //if a is inf return inf
            else if (a_e == 2**(EXP-1)) begin
                state_next <= PUT_Z;
            end 
            //if b is inf return zero
            else if (b_e == 2**(EXP-1)) begin
                state_next <= PUT_Z;
            end 
            //if a is zero return zero
            else if (($signed(a_e) == 1 - 2**(EXP-1)) && (a_m == 0)) begin
                state_next <= PUT_Z;
            end 
            //if b is zero return inf
            else if (($signed(b_e) == 1 - 2**(EXP-1)) && (b_m == 0)) begin
                state_next <= PUT_Z;
            end 
            else begin
                state_next <= NORMALISE_A;
            end
        end
        NORMALISE_A:begin
            if (a_m[FRA]) begin
                state_next <= NORMALISE_B;
            end else begin
                state_next <= NORMALISE_A;
            end
        end
        NORMALISE_B:begin
            if (b_m[FRA]) begin
                state_next <= DIVIDE_0;
            end else begin
                state_next <= NORMALISE_B;
            end
        end
        DIVIDE_0:begin
            state_next  <= DIVIDE_1;
        end
        DIVIDE_1:begin
            state_next  <= DIVIDE_2;
        end
        DIVIDE_2:begin
            if (count == 2*FRA+3) begin
                state_next <= DIVIDE_3;
            end else begin
                state_next <= DIVIDE_1;
            end
        end
        DIVIDE_3:begin
            state_next  <= NORMALISE_1;
        end
        NORMALISE_1:begin
            if (z_m[FRA] == 0 && $signed(z_e) > 2 - 2**(EXP-1)) begin
                state_next <= NORMALISE_1;
            end 
            else begin
                state_next <= NORMALISE_2;
            end
        end
        NORMALISE_2:begin
            if ($signed(z_e) < 2 - 2**(EXP-1)) begin
                state_next <= NORMALISE_2;
            end 
            else begin
                state_next <= ROUND;
        end
        end
        ROUND:begin
            state_next  <= PACK;
        end
        PACK:begin
            state_next  <= PUT_Z;
        end
        PUT_Z:begin
            state_next  <= GET_A;
        end
        default:begin
            state_next  <= GET_A;
        end
    endcase
end

always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        s_axis_a_tready <= 0;
        s_axis_b_tready <= 0;
        a               <= 0;
        b               <= 0;
        a_e             <= 0;
        b_e             <= 0;
        a_m             <= 0;
        b_m             <= 0;
        guard           <= 0;
        round_bit       <= 0;
        sticky          <= 0;
        quotient        <= 0;
        divisor         <= 0;
        dividend        <= 0; 
        remainder       <= 0;
        count           <= 0;
        result          <= 0;
        ovalid          <= 0;
    end
    else begin
        case(state_now)
            GET_A:begin
                ovalid  <= 1'b0;
                s_axis_a_tready <= 1'b1;        
                if(s_axis_a_tvalid && s_axis_a_tready)begin
                    a               <= s_axis_a_tdata;
                    s_axis_a_tready <= 1'b0;
                end
            end
            GET_B:begin
                s_axis_b_tready     <= 1'b1;
                if(s_axis_b_tvalid && s_axis_b_tready)begin
                    b               <= s_axis_b_tdata;
                    s_axis_b_tready <= 1'b0;
                end
            end
            UNPACK:begin
                a_s <= a[EXP+FRA];
                b_s <= b[EXP+FRA];
                a_e <= a[EXP+FRA-1 : FRA] - (2**(EXP-1) - 1);
                b_e <= b[EXP+FRA-1 : FRA] - (2**(EXP-1) - 1);
                a_m <= a[FRA - 1 : 0];
                b_m <= b[FRA - 1 : 0];
            end
            SPECIAL_CASES:begin
                //if a is NaN or b is NaN return NaN 
                if ((a_e == 2**(EXP-1) && a_m != 0) || (b_e == 2**(EXP-1) && b_m != 0)) begin
                    z[EXP+FRA]     <= 1'b1;
                    z[EXP+FRA:FRA] <= 2**EXP - 1;
                    z[FRA-1]       <= 1'b1;
                    z[FRA-2:0]     <= 0; 
                end 
                //if a is inf and b is inf return NaN
                else if ((a_e == 2**(EXP-1)) && (b_e == 2**(EXP-1))) begin
                    z[EXP+FRA]     <= 1'b1;
                    z[EXP+FRA:FRA] <= 2**EXP - 1;
                    z[FRA-1]       <= 1'b1;
                    z[FRA-2:0]     <= 0;
                end 
                //if a is inf return inf
                else if (a_e == 2**(EXP-1)) begin
                    //if b is zero return NaN
                    if ($signed(b_e == 1 - 2**(EXP-1)) && (b_m == 0)) begin
                        z[EXP+FRA]     <= 1'b1;
                        z[EXP+FRA:FRA] <= 2**EXP - 1;
                        z[FRA-1]       <= 1'b1;
                        z[FRA-2:0]     <= 0;
                    end
                    else begin
                        z[EXP+FRA]     <= a_s ^ b_s;
                        z[EXP+FRA:FRA] <= 2**EXP - 1;
                        z[FRA-1:0]     <= 0;
                    end
                end 
                //if b is inf return zero
                else if (b_e == 2**(EXP-1)) begin
                    z[EXP+FRA]     <= a_s ^ b_s;
                    z[EXP+FRA:FRA] <= 0;
                    z[FRA-1:0]     <= 0;
                end 
                //if a is zero return zero
                else if (($signed(a_e) == 1 - 2**(EXP-1)) && (a_m == 0)) begin
                    //if b is zero return NaN
                    if (($signed(b_e) == 1 - 2**(EXP-1)) && (b_m == 0)) begin
                        z[EXP+FRA]     <= 1'b1;
                        z[EXP+FRA:FRA] <= 2**EXP - 1;
                        z[FRA-1]       <= 1'b1;
                        z[FRA-2:0]     <= 0;
                    end
                    else begin
                        z[EXP+FRA]     <= a_s ^ b_s;
                        z[EXP+FRA:FRA] <= 0;
                        z[FRA-1:0]     <= 0;
                    end
                end 
                //if b is zero return inf
                else if (($signed(b_e) == 1 - 2**(EXP-1)) && (b_m == 0)) begin
                    z[EXP+FRA]     <= a_s ^ b_s;
                    z[EXP+FRA:FRA] <= 2**EXP - 1;
                    z[FRA-1:0]     <= 0;
                end 
                else begin
                    //Denormalised Number
                    if ($signed(a_e) == 1 - 2**(EXP-1)) begin
                        a_e <= 2 - 2**(EXP-1);
                    end 
                    else begin
                        a_m[FRA] <= 1'b1;
                    end
                    //Denormalised Number
                        if ($signed(b_e) == 1 - 2**(EXP-1)) begin
                            b_e <= 2 - 2**(EXP-1);
                        end 
                        else begin
                            b_m[FRA] <= 1'b1;
                        end
                end
            end
            NORMALISE_A:begin
                if (a_m[FRA] == 1'b0)begin
                    a_e <= a_e - 1;
                    a_m <= a_m << 1;
                end
            end
            NORMALISE_B:begin
                if (b_m[FRA] == 1'b0)begin
                    b_e <= b_e - 1;
                    b_m <= b_m << 1;
                end
            end
            DIVIDE_0:begin
                z_s       <= a_s ^ b_s;
                z_e       <= a_e - b_e;
                quotient  <= 0;
                remainder <= 0;
                count     <= 0;
                dividend  <= a_m << (FRA+4);
                divisor   <= b_m;
            end
            DIVIDE_1:begin
                quotient     <= quotient << 1;
                remainder    <= remainder << 1;
                remainder[0] <= dividend[2*FRA+4];
                dividend     <= dividend << 1;
            end
            DIVIDE_2:begin
                if (remainder >= divisor) begin
                    quotient[0] <= 1'b1;
                    remainder   <= remainder - divisor;
                end
                if (count == 2*FRA+3) begin
                    count <= 0;
                end 
                else begin
                    count <= count + 1;
                end
            end
            DIVIDE_3:begin
                z_m       <= quotient[FRA+3:3];
                guard     <= quotient[2];
                round_bit <= quotient[1];
                sticky    <= quotient[0] | (remainder != 0);
            end
            NORMALISE_1:begin
                if (z_m[FRA] == 1'b0 && $signed(z_e) > 2 - 2**(EXP-1)) begin
                    z_e       <= z_e - 1;
                    z_m       <= z_m << 1;
                    z_m[0]    <= guard;
                    guard     <= round_bit;
                    round_bit <= 0;
                end
            end
            NORMALISE_2:begin
                if ($signed(z_e) < 2 - 2**(EXP-1)) begin
                    z_e       <= z_e + 1;
                    z_m       <= z_m >> 1;
                    guard     <= z_m[0];
                    round_bit <= guard;
                    sticky    <= sticky | round_bit;
                end
            end
            ROUND:begin
                if (guard && (round_bit | sticky | z_m[0])) begin
                    z_m <= z_m + 1;
                    if (z_m == 54'hffffffffffffff) begin
                        z_e <=  z_e + 1;
                    end
                end
            end
            PACK:begin
                if ($signed(z_e) == 2 - 2**(EXP-1) && z_m[FRA] == 0) begin
                    z[EXP+FRA]       <= z_s;
                    z[EXP+FRA-1:FRA] <= 0;
                    z[FRA-1:0]       <= z_m[FRA-1:0];
                end
                //if overflow occurs, return inf
                else if ($signed(z_e) > 2**(EXP-1) - 1) begin
                    z[EXP+FRA]         <= z_s;
                    z[EXP+FRA-1 : FRA] <= 2**EXP - 1;
                    z[FRA-1 : 0]       <= 0;
                end
                else begin
                    z[EXP+FRA]       <= z_s;
                    z[EXP+FRA-1:FRA] <= z_e[EXP-1:0] + (2**(EXP-1) - 1);
                    z[FRA-1:0]       <= z_m[FRA-1:0];
                end
            end
            PUT_Z:begin
                result        <= z;
                ovalid        <= 1'b1;
            end
            default:;
        endcase
    end
end

assign m_axis_tvalid = ovalid;

always @(*) begin
    if(aresetn == 1'b0)begin
        m_axis_tdata  <= 0;
    end
    else if(m_axis_tvalid & m_axis_tready)begin
        m_axis_tdata  <= result;
    end
    else begin
        m_axis_tdata  <= m_axis_tdata;
    end
end

endmodule
 