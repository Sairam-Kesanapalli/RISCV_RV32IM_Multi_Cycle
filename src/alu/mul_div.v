module mul_div#(
    parameter WIDTH = 32
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] md_op,
    input [WIDTH-1:0] A,
    input [WIDTH-1:0] B,
    output reg [WIDTH-1:0] Result,
    output reg busy,
    output reg done
);

    // M-Extension funct3 operations
    localparam MUL    = 3'b000;
    localparam MULH   = 3'b001;
    localparam MULHSU = 3'b010;
    localparam MULHU  = 3'b011;
    localparam DIV    = 3'b100;
    localparam DIVU   = 3'b101;
    localparam REM    = 3'b110;
    localparam REMU   = 3'b111;

    // State machine for MUL/DIV latency
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;

    // Internal results
    wire signed [WIDTH*2-1:0] signed_A = $signed(A);
    wire signed [WIDTH*2-1:0] signed_B = $signed(B);
    wire [WIDTH*2-1:0] unsigned_A = { {WIDTH{1'b0}}, A };
    wire [WIDTH*2-1:0] unsigned_B = { {WIDTH{1'b0}}, B };

    reg signed [WIDTH*2-1:0] res_mulh;
    reg signed [WIDTH*2-1:0] res_mulhsu;
    reg [WIDTH*2-1:0] res_mulhu;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            Result <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC;
                        busy <= 1;
                    end
                end

                CALC: begin
                    busy <= 0;
                    done <= 1;
                    state <= DONE;                   
                                            
                    // Compute result based on operation
                    case(md_op)
                        MUL:    Result <= A * B;
                        MULH:   begin
                                    // Signed * Signed
                                    res_mulh = signed_A * signed_B;
                                    Result <= res_mulh[WIDTH*2-1:WIDTH];
                                end
                        MULHSU: begin
                                    // Signed * Unsigned
                                    res_mulhsu = signed_A * $signed({1'b0, B});
                                    Result <= res_mulhsu[WIDTH*2-1:WIDTH];
                                end
                        MULHU:  begin
                                    // Unsigned * Unsigned
                                    res_mulhu = unsigned_A * unsigned_B;
                                    Result <= res_mulhu[WIDTH*2-1:WIDTH];
                                end
                        DIV:    begin
                                    if (B == 0) Result <= {WIDTH{1'b1}}; // Division by zero
                                    else if (A == {1'b1, {(WIDTH-1){1'b0}}} && B == {WIDTH{1'b1}}) Result <= A; // Overflow
                                    else Result <= $signed(A) / $signed(B);
                                end
                        DIVU:   begin
                                    if (B == 0) Result <= {WIDTH{1'b1}}; // Division by zero
                                    else Result <= A / B;
                                end
                        REM:    begin
                                    if (B == 0) Result <= A; // Division by zero
                                    else if (A == {1'b1, {(WIDTH-1){1'b0}}} && B == {WIDTH{1'b1}}) Result <= 0; // Overflow
                                    else Result <= $signed(A) % $signed(B);
                                end
                        REMU:   begin
                                    if (B == 0) Result <= A; // Division by zero
                                    else Result <= A % B;
                                end
                        default: Result <= 0;
                    endcase
                end

                DONE: begin
                    // Stay here until start goes low, or return to IDLE immediately
                    // Since the control unit moves out of EXEC state on done, start should go low.
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
