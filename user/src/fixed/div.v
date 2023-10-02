module div #(
    parameter SYMBOL_A = "signed",
    parameter SYMBOL_B = "signed",
    parameter WIDTH_A  = 16,
    parameter WIDTH_B  = 8
) (
    input                               aclk,
    input                               aresetn,

    input   [WIDTH_A - 1 : 0]           s_axis_a_tdata,
    input                               s_axis_a_tvalid,
    output  reg                         s_axis_a_tready,

    input   [WIDTH_B - 1 : 0]           s_axis_b_tdata,
    input                               s_axis_b_tvalid,
    output  reg                         s_axis_b_tready,

    output  [WIDTH_A + WIDTH_B - 1 : 0] m_axis_tdata,
    output                              m_axis_tvalid,
    input                               m_axis_tready
);

localparam IDLE       = 0,
           SHIFT_LEFT = 1,
           COMPARISON = 2,
           PUT        = 3;
           
reg [WIDTH_A - 1 : 0] a;
reg [WIDTH_B - 1 : 0] b;
reg                   a_valid,r_a_valid,d_a_valid;
reg                   b_valid,r_b_valid,d_b_valid;

//get_a
always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        a       <= 0;
        a_valid <= 1'b0;
    end
    else if(s_axis_a_tvalid && s_axis_a_tready)begin
        a       <= s_axis_a_tdata;
        a_valid <= 1'b1;
    end
    else begin
        a       <= a;
        a_valid <= 1'b0;
    end
end

//get_b
always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        b       <= 0;
        b_valid <= 1'b0;
    end
    else if(s_axis_b_tvalid && s_axis_b_tready)begin
        b       <= s_axis_b_tdata;
        b_valid <= 1'b1;
    end
    else begin
        b       <= b;
        b_valid <= 1'b0;
    end
end

always @(posedge aclk) begin
    r_a_valid <= a_valid;
    r_a_valid <= b_valid;
    d_a_valid <= r_a_valid;
    d_b_valid <= r_b_valid;
end

//format conversion
reg [WIDTH_A + WIDTH_B - 1 : 0] r_dividen;
reg [WIDTH_A + WIDTH_B - 1 : 0] r_divisor;
reg [WIDTH_A + WIDTH_B - 1 : 0] dividen;
reg [WIDTH_A + WIDTH_B - 1 : 0] divisor;
reg [WIDTH_A + WIDTH_B - 1 : 0] remainder;
reg [WIDTH_A + WIDTH_B - 1 : 0] quotient;

generate if(SYMBOL_A == "signed")begin
    always @(posedge aclk) begin
        r_dividen <= a - 1;
        dividen   <= {r_dividen[WIDTH_A + WIDTH_B - 1],~r_dividen[WIDTH_A + WIDTH_B - 2:0]};
    end
end
else if(SYMBOL_A == "unsigned")begin
    always @(posedge aclk) begin
        r_dividen <= a;
        dividen   <= r_dividen;
    end
end
endgenerate

generate if(SYMBOL_B == "signed")begin
    always @(posedge aclk) begin
        r_divisor <= b - 1;
        divisor   <= {r_divisor[WIDTH_A + WIDTH_B - 1],~r_divisor[WIDTH_A + WIDTH_B - 2:0]};
    end
end
else if(SYMBOL_B == "unsigned")begin
    always @(posedge aclk) begin
        r_divisor <= b;
        divisor   <= r_divisor;
    end
end
endgenerate

reg [1:0]                             state_now,state_next;
reg [$clog2(WIDTH_A+WIDTH_B) - 1 : 0] cnt;
reg                                   ovalid;
reg [WIDTH_A + WIDTH_B - 1 : 0]       result;

always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        state_now <= IDLE;
    end
    else begin
        state_now <= state_next;
    end
end

always @(*) begin
    case(state_now)
        IDLE:begin
            if(d_a_valid && d_b_valid)
                state_next <= SHIFT_LEFT;
            else 
                state_next <= IDLE;
        end
        SHIFT_LEFT:begin
            state_next <= COMPARISON;
        end
        COMPARISON:begin
            if(cnt == WIDTH_A + WIDTH_B - 1)begin
                state_next <= PUT;
            end
            else begin
                state_next <= SHIFT_LEFT;
            end
        end
        PUT:begin
            state_next <= IDLE;
        end
        default:begin
            state_next <= IDLE;
        end
    endcase
end

always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        dividen   <= 0;
        divisor   <= 0;
        quotient  <= 0;
        remainder <= 0;
        ovalid    <= 0;
        result    <= 0;
    end
    else begin
        case(state_now)
            IDLE:begin
                ovalid    <= 1'b0;
                dividen   <= dividen;
                divisor   <= divisor;
                quotient  <= 0;
                remainder <= 0;
            end
            SHIFT_LEFT:begin
                dividen      <= dividen   << 1;
                quotient     <= quotient  << 1;
                remainder    <= remainder << 1;
                remainder[0] <= dividen[WIDTH_A + WIDTH_B - 1];
            end
            COMPARISON:begin
                if(remainder >= divisor)begin
                    remainder <= remainder - divisor;
                end
                if(cnt == WIDTH_A + WIDTH_B - 1)begin
                    cnt       <= 0;
                end
                else begin
                    cnt       <= cnt + 1'b1;
                end
            end
            PUT:begin
                ovalid                                  <= 1'b1;
                result[WIDTH_A + WIDTH_B - 1 : WIDTH_B] <= quotient;
                result[WIDTH_B - 1 : 0]                 <= remainder;
            end
            default:;
        endcase
    end
end

assign m_axis_tdata  = result;
assign m_axis_tvalid = ovalid;

//ready
always @(posedge aclk) begin
    if(aresetn == 1'b0)begin
        s_axis_a_tready <= 1'b1;
        s_axis_b_tready <= 1'b1;
    end
    else if(m_axis_tvalid && m_axis_tready)begin
        s_axis_a_tready <= 1'b1;
        s_axis_b_tready <= 1'b1;
    end
    else begin
        s_axis_a_tready <= 1'b0;
        s_axis_b_tready <= 1'b0;
    end
end

endmodule
