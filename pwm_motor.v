module pwm_motor(
    input clk,
    input reset,
    input enable,
    output pwm_out
);

wire [11:0] count_wire;
wire [11:0] duty_wire;

contador_pwm U1(
    .clk(clk),
    .reset(reset),
    .count(count_wire)
);

codificador_pwm U2(
    .duty(duty_wire)
);

comparador_pwm U3(
    .count(count_wire),
    .duty(duty_wire),
    .enable(enable),
    .PWM(pwm_out)
);

endmodule