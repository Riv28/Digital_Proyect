`timescale 1ns / 1ps

module top_sound_test (
    input wire clk_50mhz,        
    input wire rst_n,            
    
    // --- 1. Entrada del Sensor de Sonido LM393 ---
    input wire physical_sound_pin,  
    
    // --- 2. Interfaz Física de la Pantalla GLCD 128x64 (KS0108) ---
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire lcd_cs1,
    output wire lcd_cs2,
    output wire lcd_rst,
    output wire [7:0] lcd_data
);

    // =========================================================================
    // BLOQUE A: BASE DE TIEMPO INTERNA
    // =========================================================================
    
    // Habilitador de 1 MHz para la sincronización de la pantalla (1 ciclo clk_50mhz cada 1 us)
    reg [5:0] clk_div_1mhz;
    reg clk_en_1mhz;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_1mhz <= 6'd0;
            clk_en_1mhz  <= 1'b0;
        end else begin
            if (clk_div_1mhz == 6'd49) begin
                clk_div_1mhz <= 6'd0;
                clk_en_1mhz  <= 1'b1;
            end else begin
                clk_div_1mhz <= clk_div_1mhz + 1'b1;
                clk_en_1mhz  <= 1'b0;
            end
        end
    end

    // =========================================================================
    // BLOQUE B: CABLES DE INTERCONEXIÓN
    // =========================================================================
    wire w_sound_active;
    wire w_sound_pulse;

    wire sound_start;
    wire sound_rs;
    wire sound_cs1;
    wire sound_cs2;
    wire [7:0] sound_byte;
    wire w_drv_ready;

    assign lcd_rw = 1'b0;  // Escritura siempre activa
    assign lcd_rst = 1'b1; // Reset del chip LCD desactivado (activo en bajo)

    // =========================================================================
    // BLOQUE C: INSTANCIACIÓN DE SUBMÓDULOS
    // =========================================================================

    // Módulo del Sensor de Sonido (con debounce integrado de 10 ms)
    sensor_de_sonido u_sound_sensor (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .sound_raw(physical_sound_pin),
        .sound_active(w_sound_active),
        .sound_pulse(w_sound_pulse)
    );

    // Driver Físico GLCD
    glcd_driver u_driver (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .start(sound_start),
        .rs_in(sound_rs),
        .cs1_in(sound_cs1),
        .cs2_in(sound_cs2),
        .data_in(sound_byte),
        .lcd_rs(lcd_rs),
        .lcd_e(lcd_e),
        .lcd_cs1(lcd_cs1),
        .lcd_cs2(lcd_cs2),
        .lcd_data(lcd_data),
        .ready(w_drv_ready)
    );

    // Visualización del Estado de Sonido (Siempre activa en este top)
    glcd_sound_controller u_sound_disp (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .active(1'b1),
        .sound_active(w_sound_active),
        .drv_start(sound_start),
        .drv_rs(sound_rs),
        .drv_cs1(sound_cs1),
        .drv_cs2(sound_cs2),
        .drv_byte(sound_byte),
        .drv_ready(w_drv_ready)
    );

endmodule
