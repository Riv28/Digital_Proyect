module glcd_cat_controller (
    input wire clk_50mhz,
    input wire clk_en_1mhz,
    input wire rst_n,
    input wire active,      // <--- NUEVA ENTRADA DE ACTIVACIÓN
    input wire scroll_tick, // Pulso que indica cuándo mover el gato un píxel
    output reg drv_start,
    output reg drv_rs,
    output reg drv_cs1,
    output reg drv_cs2,
    output reg [7:0] drv_byte,
    input wire drv_ready
);

    reg [4:0] state;
    reg [4:0] return_state;
    reg [2:0] page;
    reg [6:0] x; // 0 a 127 (Ancho total de la pantalla)
    reg [15:0] init_timer;
    
    reg [4:0] scroll_offset; // 0 a 31 (Desplazamiento del mosaico)
    
    // Registro para detectar el flanco de subida de active y contador de columna de limpieza
    reg active_d;
    reg [5:0] clear_col;
    reg initialized;

    localparam ST_INIT_WAIT = 5'd0;
    localparam ST_DISP_ON   = 5'd1;
    localparam ST_START_LN  = 5'd2;
    localparam ST_SET_PAGE  = 5'd3;
    localparam ST_SET_Y     = 5'd4;
    localparam ST_WRITE_DAT = 5'd5;
    localparam ST_WAIT_DRV  = 5'd6;
    localparam ST_NEXT_PAGE = 5'd7;
    localparam ST_WAIT_SYNC = 5'd8;
    localparam ST_CLEAR_PAGE  = 5'd9;
    localparam ST_CLEAR_Y     = 5'd10;
    localparam ST_CLEAR_WRITE = 5'd11;

    // Detectores de activación
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) active_d <= 1'b0;
        else active_d <= active;
    end
    wire active_posedge = active && !active_d && initialized;

    // --- MEMORIA ROM DEL GATO (32x32 píxeles = 128 bytes) ---
    // Calculamos la dirección en base a la página del dibujo (0-3) y la columna (0-31)
    wire [6:0] rom_addr = {page[1:0], 5'd0} + ((x[4:0] + scroll_offset) % 32);
    reg [7:0] pixel_data;

    always @(*) begin
        case(rom_addr)
            // PAGINA 0: Orejas y parte superior de la cabeza
            0: pixel_data=8'h00; 1: pixel_data=8'h00; 2: pixel_data=8'h00; 3: pixel_data=8'hC0; 
            4: pixel_data=8'hF0; 5: pixel_data=8'hF8; 6: pixel_data=8'hFC; 7: pixel_data=8'h7C; 
            8: pixel_data=8'h3E; 9: pixel_data=8'h1E; 10:pixel_data=8'h0E; 11:pixel_data=8'h0E; 
            12:pixel_data=8'h0E; 13:pixel_data=8'h0E; 14:pixel_data=8'h0E; 15:pixel_data=8'h0E; 
            16:pixel_data=8'h0E; 17:pixel_data=8'h0E; 18:pixel_data=8'h0E; 19:pixel_data=8'h0E; 
            20:pixel_data=8'h0E; 21:pixel_data=8'h1E; 22:pixel_data=8'h3E; 23:pixel_data=8'h7C; 
            24:pixel_data=8'hFC; 25:pixel_data=8'hF8; 26:pixel_data=8'hF0; 27:pixel_data=8'hC0; 
            28:pixel_data=8'h00; 29:pixel_data=8'h00; 30:pixel_data=8'h00; 31:pixel_data=8'h00;
            // PAGINA 1: Ojos y frente
            32:pixel_data=8'h00; 33:pixel_data=8'hC0; 34:pixel_data=8'hF0; 35:pixel_data=8'hFF; 
            36:pixel_data=8'hFF; 37:pixel_data=8'hFF; 38:pixel_data=8'hFF; 39:pixel_data=8'hFF; 
            40:pixel_data=8'hFF; 41:pixel_data=8'h3F; 42:pixel_data=8'h3F; 43:pixel_data=8'h3F; 
            44:pixel_data=8'hFF; 45:pixel_data=8'hFF; 46:pixel_data=8'hFF; 47:pixel_data=8'hFF; 
            48:pixel_data=8'hFF; 49:pixel_data=8'hFF; 50:pixel_data=8'hFF; 51:pixel_data=8'h3F; 
            52:pixel_data=8'h3F; 53:pixel_data=8'h3F; 54:pixel_data=8'hFF; 55:pixel_data=8'hFF; 
            56:pixel_data=8'hFF; 57:pixel_data=8'hFF; 58:pixel_data=8'hFF; 59:pixel_data=8'hF0; 
            60:pixel_data=8'hC0; 61:pixel_data=8'h00; 62:pixel_data=8'h00; 63:pixel_data=8'h00;
            // PAGINA 2: Bigotes, mejillas y boca
            64:pixel_data=8'h00; 65:pixel_data=8'h03; 66:pixel_data=8'h4F; 67:pixel_data=8'h4F; 
            68:pixel_data=8'hFF; 69:pixel_data=8'hFF; 70:pixel_data=8'h2F; 71:pixel_data=8'h2F; 
            72:pixel_data=8'hFF; 73:pixel_data=8'hFF; 74:pixel_data=8'hFF; 75:pixel_data=8'hF3; 
            76:pixel_data=8'hE3; 77:pixel_data=8'hC3; 78:pixel_data=8'h83; 79:pixel_data=8'h87; 
            80:pixel_data=8'h83; 81:pixel_data=8'hC3; 82:pixel_data=8'hE3; 83:pixel_data=8'hF3; 
            84:pixel_data=8'hFF; 85:pixel_data=8'hFF; 86:pixel_data=8'hFF; 87:pixel_data=8'h2F; 
            88:pixel_data=8'h2F; 89:pixel_data=8'hFF; 90:pixel_data=8'hFF; 91:pixel_data=8'h4F; 
            92:pixel_data=8'h4F; 93:pixel_data=8'h03; 94:pixel_data=8'h00; 95:pixel_data=8'h00;
            // PAGINA 3: Mentón
            96:pixel_data=8'h00; 97:pixel_data=8'h00; 98:pixel_data=8'h00; 99:pixel_data=8'h00; 
            100:pixel_data=8'h01;101:pixel_data=8'h03;102:pixel_data=8'h07;103:pixel_data=8'h0F;
            104:pixel_data=8'h0F;105:pixel_data=8'h1F;106:pixel_data=8'h1F;107:pixel_data=8'h3F;
            108:pixel_data=8'h3F;109:pixel_data=8'h3F;110:pixel_data=8'h3F;111:pixel_data=8'h3F;
            112:pixel_data=8'h3F;113:pixel_data=8'h3F;114:pixel_data=8'h3F;115:pixel_data=8'h3F;
            116:pixel_data=8'h3F;117:pixel_data=8'h1F;118:pixel_data=8'h1F;119:pixel_data=8'h0F;
            120:pixel_data=8'h0F;121:pixel_data=8'h07;122:pixel_data=8'h03;123:pixel_data=8'h01;
            124:pixel_data=8'h00;125:pixel_data=8'h00;126:pixel_data=8'h00;127:pixel_data=8'h00;
            default: pixel_data=8'h00;
        endcase
    end

    // --- LÓGICA DE ACTUALIZACIÓN DEL DESPLAZAMIENTO ---
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) scroll_offset <= 5'd0;
        else if (scroll_tick) scroll_offset <= scroll_offset + 1'b1; // Mueve el mosaico 1 píxel a la izquierda
    end

    // --- MÁQUINA DE ESTADOS DE DIBUJO CONTÍNUO ---
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_INIT_WAIT;
            init_timer <= 16'd0;
            page       <= 3'd0;
            x          <= 7'd0;
            drv_start  <= 1'b0;
            clear_col  <= 6'd0;
            drv_rs     <= 1'b0;
            drv_cs1    <= 1'b0;
            drv_cs2    <= 1'b0;
            drv_byte   <= 8'h00;
            return_state <= ST_INIT_WAIT;
            initialized <= 1'b0;
        end else if (active_posedge) begin
            // Al activarse el módulo, forzar la secuencia de limpieza de pantalla
            page       <= 3'd0;
            clear_col  <= 6'd0;
            state      <= ST_CLEAR_PAGE;
            drv_start  <= 1'b0;
        end else if (clk_en_1mhz) begin
            case (state)
                ST_INIT_WAIT: begin
                    if (init_timer == 16'd50000) state <= ST_DISP_ON;
                    else init_timer <= init_timer + 1'b1;
                end
                
                ST_DISP_ON: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'h3F; drv_start <= 1'b1;
                        return_state <= ST_START_LN; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_START_LN: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'hC0; drv_start <= 1'b1;
                        initialized <= 1'b1;
                        page <= 3'd0;
                        clear_col <= 6'd0;
                        return_state <= ST_CLEAR_PAGE; state <= ST_WAIT_DRV;
                    end
                end

                // Bucle Principal de Dibujo: Recorre páginas y columnas
                ST_SET_PAGE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; 
                        // Activa el Chip Select correcto según en qué mitad de la pantalla estamos
                        drv_cs1 <= (x < 64) ? 1'b1 : 1'b0;
                        drv_cs2 <= (x >= 64) ? 1'b1 : 1'b0;
                        drv_byte <= 8'hB8 | {5'b00000, page};
                        drv_start <= 1'b1;
                        return_state <= ST_SET_Y; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_SET_Y: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0;
                        // El KS0108 cuenta de 0 a 63 para cada mitad
                        drv_byte <= 8'h40 | (x[5:0]); 
                        drv_start <= 1'b1;
                        return_state <= ST_WRITE_DAT; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_WRITE_DAT: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b1;
                        drv_byte <= pixel_data; // Lee el píxel de la ROM calculada
                        drv_start <= 1'b1;
                        
                        // Lógica de avance
                        if (x == 7'd127) begin
                            x <= 7'd0;
                            return_state <= ST_NEXT_PAGE;
                        end else if (x == 7'd63) begin
                            x <= 7'd64; // Cruzamos a la mitad derecha, requiere reconfigurar CS2
                            return_state <= ST_SET_PAGE;
                        end else begin
                            x <= x + 1'b1;
                            return_state <= ST_WRITE_DAT; // El KS0108 auto-incrementa Y
                        end
                        state <= ST_WAIT_DRV;
                    end
                end

                ST_NEXT_PAGE: begin
                    if (page == 3'd7) begin
                        page <= 3'd0;
                        state <= ST_WAIT_SYNC; // Terminó un fotograma completo
                    end else begin
                        page <= page + 1'b1;
                        state <= ST_SET_PAGE;
                    end
                end

                ST_WAIT_SYNC: begin
                    // Reinicia el ciclo inmediatamente para mantener la pantalla fluida
                    state <= ST_SET_PAGE; 
                end

                // --- ESTADOS NUEVOS PARA LIMPIEZA DE PANTALLA ---
                ST_CLEAR_PAGE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1; // Ambos controladores activos
                        drv_byte <= 8'hB8 | page; 
                        drv_start <= 1'b1;
                        return_state <= ST_CLEAR_Y; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_CLEAR_Y: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'h40; // Y = 0
                        drv_start <= 1'b1;
                        return_state <= ST_CLEAR_WRITE; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_CLEAR_WRITE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b1; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'h00; // Escribe 0 (vacío) en ambos lados a la vez
                        drv_start <= 1'b1;
                        
                        if (clear_col == 6'd63) begin
                            clear_col <= 6'd0;
                            if (page == 3'd7) begin
                                page <= 3'd0;
                                x <= 7'd0;
                                return_state <= ST_SET_PAGE; // Ir a la pantalla de dibujo normal
                            end else begin
                                page <= page + 1'b1;
                                return_state <= ST_CLEAR_PAGE;
                            end
                        end else begin
                            clear_col <= clear_col + 1'b1;
                            return_state <= ST_CLEAR_WRITE;
                        end
                        state <= ST_WAIT_DRV;
                    end
                end

                ST_WAIT_DRV: begin
                    drv_start <= 1'b0;
                    if (drv_ready) state <= return_state;
                end
                
                default: state <= ST_SET_PAGE;
            endcase
        end
    end
endmodule