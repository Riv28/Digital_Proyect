`timescale 1ns / 1ps

module hx711_controller #(
    // Parámetros por defecto (Los cambiaremos en la caracterización)
    parameter SCALE_MULT = 0,      
    parameter SCALE_SHIFT = 0,
    parameter FILTER_SHIFT = 2 // Filtro IIR: 2 es rápido y reactivo (tarda ~1s), 4 es lento pero filtra más ruido
)(
    input wire clk_50mhz,
    input wire rst_n,
    input wire tare_req,   // Señal de tara proveniente de la FSM
    input wire dout,       // Pin físico conectado a DOUT del HX711
    output reg sck,        // Pin físico conectado a SCK del HX711
    
    output reg [15:0] weight_bcd, // Peso en BCD (4 dígitos)
    output reg weight_sign,       // 1 si es negativo
    output reg weight_ready       // Pulso indicando dato fresco y válido
);

    // =================================================================
    // 1. DIVISOR DE RELOJ PARA EL SCK DEL HX711 (~1 MHz)
    // =================================================================
    reg [5:0] clk_div;
    wire clk_1mhz_en = (clk_div == 6'd49);

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) clk_div <= 0;
        else if (clk_1mhz_en) clk_div <= 0;
        else clk_div <= clk_div + 1;
    end

    // =================================================================
    // 2. FSM DEL PROTOCOLO HX711 (Bit-banging)
    // =================================================================
    localparam IDLE  = 1'b0,
               READ  = 1'b1;

    reg state;
    reg [5:0] bit_count;
    reg signed [23:0] shift_reg;
    reg signed [23:0] raw_data_reg;
    reg data_ready_flag;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sck <= 1'b0;
            bit_count <= 6'd0;
            shift_reg <= 24'd0;
            raw_data_reg <= 24'd0;
            data_ready_flag <= 1'b0;
        end else if (clk_1mhz_en) begin
            data_ready_flag <= 1'b0; 
            
            case (state)
                IDLE: begin
                    sck <= 1'b0;
                    bit_count <= 6'd0;
                    if (dout == 1'b0) state <= READ; // HX711 listo
                end
                
                READ: begin
                    sck <= ~sck;
                    if (~sck) begin // Flanco de subida de SCK (sck era 0)
                        bit_count <= bit_count + 1'b1;
                        if (bit_count < 6'd24) begin
                            shift_reg <= {shift_reg[22:0], dout};
                        end
                    end else begin // Flanco de bajada de SCK (sck era 1)
                        if (bit_count == 6'd25) begin
                            raw_data_reg <= shift_reg;
                            data_ready_flag <= 1'b1; // Levantamos bandera
                            state <= IDLE;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end else begin
            data_ready_flag <= 1'b0;
        end
    end

    // =================================================================
    // 3. RUTA DE DATOS (FILTRADO IIR, TARA Y ESCALADO MATEMÁTICO)
    // =================================================================
    reg signed [23:0] filtered_raw_data;
    reg [3:0] filter_init_counter;
    reg signed [23:0] offset_reg;
    
    // Cálculo combinacional del siguiente valor filtrado para evitar latencia de 1 ciclo en la salida
    wire signed [23:0] next_filtered_raw_data = (filter_init_counter < 4'd10) ? raw_data_reg :
                                                 (filtered_raw_data + ((raw_data_reg - filtered_raw_data) >>> FILTER_SHIFT));
                                                
    // Usamos el valor filtrado entrante en el ciclo donde data_ready_flag es alto para el escalado inmediato
    wire signed [23:0] active_filtered_data = data_ready_flag ? next_filtered_raw_data : filtered_raw_data;
    
    wire signed [23:0] net_data = active_filtered_data - offset_reg;
    wire signed [31:0] scaled_data = (net_data * $signed(SCALE_MULT)) >>> SCALE_SHIFT;
    reg [13:0] abs_weight_bin;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            filtered_raw_data   <= 24'sd0;
            filter_init_counter <= 4'd0;
            offset_reg          <= 24'sd0;
            weight_ready        <= 1'b0;
            weight_sign         <= 1'b0;
            abs_weight_bin      <= 14'd0;
        end else begin
            weight_ready <= 1'b0; 
            
            // La señal de tara guarda el valor filtrado actual
            if (tare_req) begin
                offset_reg <= filtered_raw_data;
            end
            
            // Cuando llega una lectura fresca del HX711, operamos
            if (data_ready_flag) begin
                // Actualizamos el filtro IIR de primer orden
                filtered_raw_data <= next_filtered_raw_data;
                if (filter_init_counter < 4'd10) begin
                    filter_init_counter <= filter_init_counter + 1'b1;
                end
                
                weight_ready <= 1'b1; // Notificamos al top module
                if (scaled_data < 0) begin
                    weight_sign <= 1'b1;
                    abs_weight_bin <= (-scaled_data > 32'sd9999) ? 14'd9999 : -scaled_data[13:0];
                end else begin
                    weight_sign <= 1'b0;
                    abs_weight_bin <= (scaled_data > 32'sd9999) ? 14'd9999 : scaled_data[13:0];
                end
            end
        end
    end

    // =================================================================
    // 4. CONVERSOR BINARIO A BCD (DOUBLE DABBLE HARDWARE)
    // =================================================================
    integer i;
    reg [15:0] bcd_temp;
    
    always @(*) begin
        bcd_temp = 16'd0;
        for (i = 13; i >= 0; i = i - 1) begin
            if (bcd_temp[3:0] >= 5)   bcd_temp[3:0]   = bcd_temp[3:0] + 3;
            if (bcd_temp[7:4] >= 5)   bcd_temp[7:4]   = bcd_temp[7:4] + 3;
            if (bcd_temp[11:8] >= 5)  bcd_temp[11:8]  = bcd_temp[11:8] + 3;
            if (bcd_temp[15:12] >= 5) bcd_temp[15:12] = bcd_temp[15:12] + 3;
            bcd_temp = {bcd_temp[14:0], abs_weight_bin[i]};
        end
        weight_bcd = bcd_temp;
    end

endmodule