module contador_pwm(
    input clk,
    input reset,
    output reg [11:0] count
);

always @(posedge clk)
begin
    count <= (!reset) ? 12'd0 :
             (count == 12'd2499) ? 12'd0 :
             count + 1'b1;
end

endmodule