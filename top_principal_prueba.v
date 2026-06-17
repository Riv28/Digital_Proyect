`timescale 1ns / 1ps

module top_principal_prueba (
    input wire clk_50mhz,        
    input wire rst_n,            
    
    // --- 1. Entrada del Sensor de Sonido LM393 ---
    input wire physical_sound_pin, 
    
    // --- 2. Botón Físico de Tara ---
    input wire physical_tare_pin,  
    
    // --- 3. Módulo HX711 (Celda de Carga) ---
    input wire hx711_dout,       
    output wire hx711_sck,       
    
    // --- 4. Control de Motor y LED ---
    output wire motor_in1,       
    output wire motor_led,       
    
    // --- 5. Interfaz Física de la Pantalla GLCD 128x64 (KS0108) ---
    output wire lcd_rs,
    output wire lcd_rw,
    output wire lcd_e,
    output wire lcd_cs1,
    output wire lcd_cs2,
    output wire lcd_rst,
    output wire [7:0] lcd_data
);

    // =========================================================================
    // BLOQUE A: CONFIGURACIÓN DE PARÁMETROS Y BASES DE TIEMPO
    // =========================================================================
    
    // === CONFIGURACIÓN DEL TIEMPO DE COOLDOWN (DESCANSO) ===
    // Para pruebas de laboratorio: 30 segundos
    localparam [15:0] COOLDOWN_SECS = 16'd30;
    // Para el funcionamiento real (2 horas = 7200 segundos), descomenta la siguiente línea y comenta la anterior:
    // localparam [15:0] COOLDOWN_SECS = 16'd7200;

    // === LÍMITE DE PESO ESTABLECIDO ===
    localparam [15:0] TARGET_WEIGHT_BCD = 16'h0040; // 40 gramos (En BCD)

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

    // 2. Reloj de Tick (1 ms) para los retardos internos
    reg [15:0] clk_div_ms;
    reg tick_ms;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_ms <= 16'd0;
            tick_ms    <= 1'b0;
        end else begin
            if (clk_div_ms == 16'd24999) begin // 25,000 ciclos clk_50mhz = 1 ms a 50 MHz
                clk_div_ms <= 16'd0;
                tick_ms    <= 1'b1; 
            end else begin
                clk_div_ms <= clk_div_ms + 1'b1;
                tick_ms    <= 1'b0;
            end
        end
    end

    // 3. Divisor de 1 segundo para el countdown del cooldown
    reg [9:0] ms_counter;
    reg tick_sec;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter <= 10'd0;
            tick_sec   <= 1'b0;
        end else if (tick_ms) begin
            if (ms_counter == 10'd999) begin // 1000 ms = 1 segundo
                ms_counter <= 10'd0;
                tick_sec   <= 1'b1;
            end else begin
                ms_counter <= ms_counter + 1'b1;
                tick_sec   <= 1'b0;
            end
        end else begin
            tick_sec <= 1'b0;
        end
    end

    // =========================================================================
    // BLOQUE B: ANTIRREBOTES PARA EL BOTÓN DE TARA
    // =========================================================================
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

    assign tare_btn_pressed = (last_tare_db_state == 1'b1) && (tare_db_state == 1'b0);

    // =========================================================================
    // BLOQUE C: CABLES DE INTERCONEXIÓN
    // =========================================================================
    wire w_sound_active;
    wire w_sound_pulse;

    wire [15:0] w_weight_bcd;   
    wire w_weight_sign;         
    wire w_weight_ready;        

    reg r_scale_tare;           // Señal de tara de la FSM
    reg r_motor_run;            // Señal de encendido del motor de la FSM

    wire status_start;
    wire status_rs;
    wire status_cs1;
    wire status_cs2;
    wire [7:0] status_byte;
    wire w_drv_ready;

    assign lcd_rw = 1'b0; 
    assign lcd_rst = 1'b1; 

    // =========================================================================
    // BLOQUE D: MÁQUINA DE ESTADOS FINITA (FSM) DEL COMEDERO
    // =========================================================================
    reg [2:0] state;
    reg [15:0] timer_ms; 
    reg [15:0] cooldown_sec; // Contador regresivo en segundos

    localparam ST_IDLE         = 3'd0;
    localparam ST_TARE         = 3'd1;
    localparam ST_DISPENSE     = 3'd2;
    localparam ST_CHECK_WEIGHT = 3'd3;
    localparam ST_COOLDOWN     = 3'd4;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            timer_ms     <= 16'd0;
            r_scale_tare <= 1'b0;
            r_motor_run  <= 1'b0;
            cooldown_sec <= 16'd0;
        end else begin
            case (state)
                
                // Reposo: Espera maullido o botón de tara físico
                ST_IDLE: begin
                    r_motor_run  <= 1'b0;
                    r_scale_tare <= 1'b0; 
                    timer_ms     <= 16'd0;
                    cooldown_sec <= 16'd0;
                    
                    if (w_sound_pulse) begin
                        state <= ST_TARE;
                    end else if (tare_btn_pressed) begin
                        state <= ST_TARE;
                    end
                end

                // Tara: Espera a que la celda de carga se establezca en cero (500 ms)
                ST_TARE: begin
                    r_scale_tare <= 1'b1; 
                    r_motor_run  <= 1'b0;
                    
                    if (tick_ms) timer_ms <= timer_ms + 1'b1;
                    if (timer_ms >= 16'd500) begin
                        timer_ms <= 16'd0;
                        state    <= ST_DISPENSE;
                    end
                end

                // Dispensación: Enciende el motor (200 ms de encendido mínimo inicial)
                ST_DISPENSE: begin
                    r_scale_tare <= 1'b0; 
                    r_motor_run  <= 1'b1; 
                    
                    if (tick_ms) timer_ms <= timer_ms + 1'b1;
                    if (timer_ms >= 16'd200) begin
                        timer_ms <= 16'd0;
                        state    <= ST_CHECK_WEIGHT;
                    end
                end

                // Chequeo de Peso: Motor sigue encendido hasta alcanzar el límite (40g)
                ST_CHECK_WEIGHT: begin
                    r_scale_tare <= 1'b0;
                    r_motor_run  <= 1'b1; 
                    
                    if (w_weight_ready && !w_weight_sign && (w_weight_bcd >= TARGET_WEIGHT_BCD)) begin
                        timer_ms     <= 16'd0;
                        cooldown_sec <= COOLDOWN_SECS;
                        state        <= ST_COOLDOWN;
                    end
                end

                // Descanso (Cooldown): Apaga el motor y bloquea nuevas activaciones por un tiempo definido
                ST_COOLDOWN: begin
                    r_scale_tare <= 1'b0;
                    r_motor_run  <= 1'b0; 
                    
                    if (tick_sec) begin
                        if (cooldown_sec > 16'd0) begin
                            cooldown_sec <= cooldown_sec - 1'b1;
                        end
                    end
                    
                    if (cooldown_sec == 16'd0) begin
                        state <= ST_IDLE;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

    // =========================================================================
    // BLOQUE E: INSTANCIACIÓN DE SUBMÓDULOS
    // =========================================================================

    // Módulo Sensor de Sonido LM393 con detector de envolvente
    sensor_de_sonido u_sound (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .sound_raw(physical_sound_pin),
        .sound_active(w_sound_active),
        .sound_pulse(w_sound_pulse)
    );

    // Controlador de Celda de Carga HX711 con filtro IIR integrado
    hx711_controller #(
        .SCALE_MULT(32'd152),   
        .SCALE_SHIFT(16)        
    ) u_load_cell (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .tare_req(r_scale_tare), 
        .dout(hx711_dout),
        .sck(hx711_sck),
        .weight_bcd(w_weight_bcd),
        .weight_sign(w_weight_sign),
        .weight_ready(w_weight_ready)
    );

    // Driver Físico GLCD 128x64
    glcd_driver u_driver (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .start(status_start),
        .rs_in(status_rs),
        .cs1_in(status_cs1),
        .cs2_in(status_cs2),
        .data_in(status_byte),
        .lcd_rs(lcd_rs),
        .lcd_e(lcd_e),
        .lcd_cs1(lcd_cs1),
        .lcd_cs2(lcd_cs2),
        .lcd_data(lcd_data),
        .ready(w_drv_ready)
    );

    // Controlador de Visualización de 4 Líneas de Estado
    glcd_status_controller u_status_disp (
        .clk_50mhz(clk_50mhz),
        .clk_en_1mhz(clk_en_1mhz),
        .rst_n(rst_n),
        .sound_active(w_sound_active),
        .weight_bcd(w_weight_bcd),
        .weight_sign(w_weight_sign),
        .motor_active(r_motor_run),
        .cooldown_ticks(cooldown_sec),
        .cooldown_active(state == ST_COOLDOWN),
        .fsm_state(state),
        .drv_start(status_start),
        .drv_rs(status_rs),
        .drv_cs1(status_cs1),
        .drv_cs2(status_cs2),
        .drv_byte(status_byte),
        .drv_ready(w_drv_ready)
    );

    // Control directo Todo/Nada (ON/OFF) del motor (IN1 del puente H L298N)
    assign motor_in1 = r_motor_run;

    // El LED se enciende de manera continua cuando el motor está habilitado
    assign motor_led = r_motor_run; 

endmodule
