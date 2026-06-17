module glcd_driver (
    input wire clk_50mhz,
    input wire clk_en_1mhz,
    input wire rst_n,
    input wire start,
    input wire rs_in,
    input wire cs1_in,
    input wire cs2_in,
    input wire [7:0] data_in,
    
    output reg lcd_rs,
    output reg lcd_e,
    output reg lcd_cs1,
    output reg lcd_cs2,
    output reg [7:0] lcd_data,
    output reg ready
);
    reg [2:0] state;
    reg [7:0] delay_cnt;

    localparam ST_IDLE  = 3'd0;
    localparam ST_SETUP = 3'd1;
    localparam ST_PULSE = 3'd2;
    localparam ST_HOLD  = 3'd3;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            lcd_rs   <= 1'b0;
            lcd_e    <= 1'b0;
            lcd_cs1  <= 1'b0;
            lcd_cs2  <= 1'b0;
            lcd_data <= 8'h00;
            ready    <= 1'b1;
            state    <= ST_IDLE;
        end else if (clk_en_1mhz) begin
            case (state)
                ST_IDLE: begin
                    lcd_e <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        lcd_rs   <= rs_in;
                        lcd_cs1  <= cs1_in;
                        lcd_cs2  <= cs2_in;
                        lcd_data <= data_in;
                        ready    <= 1'b0;
                        state    <= ST_SETUP;
                    end
                end
                ST_SETUP: begin // Pequeño retardo para estabilizar datos
                    lcd_e <= 1'b1;
                    delay_cnt <= 8'd0;
                    state <= ST_PULSE;
                end
                ST_PULSE: begin // Pulso E alto
                    if (delay_cnt == 8'd2) begin
                        lcd_e <= 1'b0; // Flanco de bajada (escribe)
                        delay_cnt <= 8'd0;
                        state <= ST_HOLD;
                    end else delay_cnt <= delay_cnt + 1'b1;
                end
                ST_HOLD: begin // Retardo de recuperación entre comandos
                    if (delay_cnt == 8'd10) begin
                        ready <= 1'b1;
                        state <= ST_IDLE;
                    end else delay_cnt <= delay_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule