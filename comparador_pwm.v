module comparador_pwm(
    input [11:0] count,
    input [11:0] duty,
    input enable,
    output PWM
);

assign PWM = enable && (count < duty);

endmodule