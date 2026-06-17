module top_calibration_system (
    input wire clk_50mhz,        
    input wire rst_n,            
    
    // --- 1. Botón de Tara ---
    input wire physical_tare_pin,  
    
    // --- 2. Módulo HX711 (Celda de Carga) ---
    input wire hx711_dout,       
    output wire hx711_sck,       
    
    // --- 3. Interfaz Física de la Pantalla GLCD 128x64 (KS0108) ---
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire lcd_cs1,
    output wire lcd_cs2,
    output wire lcd_rst,
    output wire [7:0] lcd_data
);

    // =========================================================================
    // BLOQUE A: BASES DE TIEMPO INTERNAS Y DEBOUNCERS
    // =========================================================================
    
    // 1. Pulso Habilitador de 1 MHz para la pantalla (1 ciclo clk_50mhz cada 1 us)
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

    // 2. Debouncer para physical_tare_pin (botón de tara, activo en bajo)
    reg [18:0] tare_db_cnt;
    reg tare_db_state;
    reg tare_s0, tare_s1;
    reg last_tare_db_state;
    wire tare_btn_pressed;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            tare_s0            <= 1'b1;
            tare_s1            <= 1'b1;
            tare_db_cnt        <= 19'd0;
            tare_db_state      <= 1'b1;
            last_tare_db_state <= 1'b1;
        end else begin
            tare_s0 <= physical_tare_pin;
            tare_s1 <= tare_s0;
            
            last_tare_db_state <= tare_db_state;
            
            if (tare_s1 == tare_db_state) begin
                tare_db_cnt <= 19'd0;
            end else begin
                tare_db_cnt <= tare_db_cnt + 1'b1;
                if (tare_db_cnt == 19'd500000) begin // ~10 ms
                    tare_db_state <= tare_s1;
                    tare_db_cnt <= 19'd0;
                end
            end
        end
    end

    // Detección de flanco de bajada (presionado)
    assign tare_btn_pressed = (last_tare_db_state == 1'b1) && (tare_db_state == 1'b0);

    // =========================================================================
    // BLOQUE B: CABLES DE INTERCONEXIÓN
    // =========================================================================
    wire [15:0] w_weight_bcd;   
    wire w_weight_sign;         
    wire w_weight_ready;        

    wire scale_start;
    wire scale_rs;
    wire scale_cs1;
    wire scale_cs2;
    wire [7:0] scale_byte;
    wire w_drv_ready;

    assign lcd_rw = 1'b0; 
    assign lcd_rst = 1'b1; 

    // =========================================================================
    // BLOQUE C: INSTANCIACIÓN DE SUBMÓDULOS
    // =========================================================================

    // Driver Físico GLCD
    glcd_driver u_driver (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .start(scale_start),
        .rs_in(scale_rs),
        .cs1_in(scale_cs1),
        .cs2_in(scale_cs2),
        .data_in(scale_byte),
        .lcd_rs(lcd_rs),
        .lcd_e(lcd_e),
        .lcd_cs1(lcd_cs1),
        .lcd_cs2(lcd_cs2),
        .lcd_data(lcd_data),
        .ready(w_drv_ready)
    );

    // Visualización del Peso (Activa todo el tiempo)
    glcd_scale_controller u_scale_disp (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .active(1'b1), // Siempre activa para borrar pantalla al inicio e imprimir continuamente
        .weight_bcd(w_weight_bcd),
        .weight_sign(w_weight_sign),
        .weight_ready(w_weight_ready),
        .drv_start(scale_start),
        .drv_rs(scale_rs),
        .drv_cs1(scale_cs1),
        .drv_cs2(scale_cs2),
        .drv_byte(scale_byte),
        .drv_ready(w_drv_ready)
    );
    
    // Controlador de la Celda de Carga HX711
    hx711_controller #(
        .SCALE_MULT(32'd1385),   // Parámetro de calibración a modificar en tus pruebas
        .SCALE_SHIFT(16)        // Desplazamiento base
    ) u_load_cell (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .tare_req(tare_btn_pressed), // La tara se ejecuta al pulsar el botón físico
        .dout(hx711_dout),
        .sck(hx711_sck),
        .weight_bcd(w_weight_bcd),
        .weight_sign(w_weight_sign),
        .weight_ready(w_weight_ready)
    );

endmodule
