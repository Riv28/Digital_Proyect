module top_glcd_system (
    input wire clk_50mhz,
    input wire rst_n,
    
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire lcd_cs1,
    output wire lcd_cs2,
    output wire lcd_rst,
    output wire [7:0] lcd_data
);

    assign lcd_rw = 1'b0; 
    assign lcd_rst = 1'b1; // ¡Mantenemos el parche del reset!

    reg [5:0] clk_div_1mhz;
    reg clk_1mhz;
    
    // Divisor para la velocidad de la animación (Aprox 25 Hz)
    reg [20:0] clk_div_scroll;
    reg scroll_tick;

    always @(posedge clk_50mhz) begin
        // Generador de 1 MHz para el driver
        if (clk_div_1mhz == 6'd24) begin
            clk_div_1mhz <= 6'd0;
            clk_1mhz     <= !clk_1mhz;
        end else clk_div_1mhz <= clk_div_1mhz + 1'b1;
        
        // Generador de velocidad de desplazamiento
        if (clk_div_scroll == 21'd1000000) begin
            clk_div_scroll <= 21'd0;
            scroll_tick    <= !scroll_tick;
        end else clk_div_scroll <= clk_div_scroll + 1'b1;
    end

    wire w_drv_start, w_drv_rs, w_drv_cs1, w_drv_cs2, w_drv_ready;
    wire [7:0] w_drv_byte;


    wire [15:0] w_weight_bcd;
    wire w_weight_sign;
    wire w_weight_ready;
    
    // Instancia del Driver Físico (Este archivo se queda exactamente igual)
    glcd_driver u_driver (
        .clk_1mhz(clk_1mhz),
        .rst_n(rst_n),
        .start(w_drv_start),
        .rs_in(w_drv_rs),
        .cs1_in(w_drv_cs1),
        .cs2_in(w_drv_cs2),
        .data_in(w_drv_byte),
        .lcd_rs(lcd_rs),
        .lcd_e(lcd_e),
        .lcd_cs1(lcd_cs1),
        .lcd_cs2(lcd_cs2),
        .lcd_data(lcd_data),
        .ready(w_drv_ready)
    );

    // NUEVA Instancia: Generador del patrón animado del Gato
    glcd_scale_controller u_scale_disp (
        .clk_1mhz(clk_1mhz),
        .rst_n(rst_n),
        .weight_bcd(w_weight_bcd),
        .weight_sign(w_weight_sign),
        .weight_ready(w_weight_ready),
        .drv_start(w_drv_start),
        .drv_rs(w_drv_rs),
        .drv_cs1(w_drv_cs1),
        .drv_cs2(w_drv_cs2),
        .drv_byte(w_drv_byte),
        .drv_ready(w_drv_ready)
    );

endmodule