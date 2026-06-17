module codificador_pwm(
    output reg [11:0] duty
);

always @(*) begin

    duty = 12'd1750; // 70%

end

endmodule