module glcd_scale_controller (
    input wire clk_50mhz,
    input wire clk_en_1mhz,
    input wire rst_n,
    input wire active,      // <--- NUEVA ENTRADA DE ACTIVACIÓN
    
    // --- Interfaz con el módulo de la celda de carga HX711 ---
    input wire [15:0] weight_bcd, 
    input wire weight_sign,
    input wire weight_ready,
    
    // --- Interfaz con el GLCD Driver ---
    output reg drv_start,
    output reg drv_rs,
    output reg drv_cs1,
    output reg drv_cs2,
    output reg [7:0] drv_byte,
    input wire drv_ready
);

    reg [15:0] weight_bcd_reg;
    reg weight_sign_reg;
    reg refresh_req;
    
    // Registro para detectar flanco de active, contador de columna y página de limpieza
    reg active_d;
    reg [5:0] clear_col;
    reg [2:0] page;
    reg initialized;

    // Captura síncrona del dato de la balanza
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            weight_bcd_reg  <= 16'd0;
            weight_sign_reg <= 1'b0;
            refresh_req     <= 1'b0;
        end else if (weight_ready) begin
            weight_bcd_reg  <= weight_bcd;
            weight_sign_reg <= weight_sign;
            refresh_req     <= 1'b1; // Solicita redibujar la pantalla
        end else if (clk_en_1mhz) begin
            if (state == ST_IDLE && refresh_req) begin
                refresh_req <= 1'b0;
            end
        end
    end

    // Máquina de estados para dibujar el texto
    reg [4:0] state;
    reg [4:0] return_state;
    reg [15:0] init_timer;
    reg [4:0] char_idx; // 0 a 16
    reg [2:0] pixel_col; // 0 a 5 (5 de letra + 1 espacio)
    
    // Columna absoluta en la pantalla (0 a 127)
    wire [6:0] abs_col = ({2'b00, char_idx} * 7'd6) + {4'b0000, pixel_col};
    
    wire [7:0] current_pixel_data;
    
    reg [7:0] char_code;
    
    // Detectores de activación
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) active_d <= 1'b0;
        else active_d <= active;
    end
    wire active_posedge = active && !active_d && initialized;

    // Decodificador combinacional de caracteres (para evitar latches)
    always @(*) begin
        case (char_idx)
            5'd0:  char_code = 8'h43; // 'C'
            5'd1:  char_code = 8'h4F; // 'O'
            5'd2:  char_code = 8'h4D; // 'M'
            5'd3:  char_code = 8'h49; // 'I'
            5'd4:  char_code = 8'h44; // 'D'
            5'd5:  char_code = 8'h41; // 'A'
            5'd6:  char_code = 8'h20; // ' '
            5'd7:  char_code = 8'h45; // 'E'
            5'd8:  char_code = 8'h53; // 'S'
            5'd9:  char_code = 8'h3A; // ':'
            5'd10: char_code = weight_sign_reg ? 8'h2D : 8'h20; // Signo '-' o espacio
            5'd11: char_code = {4'b0011, weight_bcd_reg[15:12]}; // Miles
            5'd12: char_code = {4'b0011, weight_bcd_reg[11:8]};  // Centenas
            5'd13: char_code = {4'b0011, weight_bcd_reg[7:4]};   // Decenas
            5'd14: char_code = {4'b0011, weight_bcd_reg[3:0]};   // Unidades
            5'd15: char_code = 8'h20; // ' '
            5'd16: char_code = 8'h67; // 'g'
            default: char_code = 8'h20; // ' '
        endcase
    end

    // Instancia de la memoria ROM
    font_rom u_font (
        .char_code(char_code),
        .col(pixel_col),
        .pixel_data(current_pixel_data)
    );

    localparam ST_INIT_WAIT = 5'd0;
    localparam ST_DISP_ON   = 5'd1;
    localparam ST_START_LN  = 5'd2;
    localparam ST_IDLE      = 5'd3;
    localparam ST_SET_PAGE  = 5'd4;
    localparam ST_SET_Y     = 5'd5;
    localparam ST_WRITE_DAT = 5'd6;
    localparam ST_WAIT_DRV  = 5'd7;
    localparam ST_CLEAR_PAGE  = 5'd8;
    localparam ST_CLEAR_Y     = 5'd9;
    localparam ST_CLEAR_WRITE = 5'd10;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_INIT_WAIT;
            init_timer <= 0; 
            char_idx <= 0; 
            pixel_col <= 0; 
            drv_start <= 0;
            drv_rs <= 0; 
            drv_cs1 <= 0; 
            drv_cs2 <= 0; 
            drv_byte <= 8'h00;
            return_state <= ST_INIT_WAIT;
            clear_col <= 6'd0;
            page <= 3'd0;
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
                        drv_rs <= 0; drv_cs1 <= 1; drv_cs2 <= 1; drv_byte <= 8'h3F; drv_start <= 1;
                        return_state <= ST_START_LN; state <= ST_WAIT_DRV;
                    end
                end
                ST_START_LN: begin
                    if (drv_ready) begin
                        drv_rs <= 0; drv_cs1 <= 1; drv_cs2 <= 1; drv_byte <= 8'hC0; drv_start <= 1;
                        initialized <= 1'b1;
                        page <= 3'd0;
                        clear_col <= 6'd0;
                        return_state <= ST_CLEAR_PAGE; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_IDLE: begin
                    // Esperamos a que la celda de carga avise que hay nuevo peso
                    if (refresh_req) begin
                        char_idx <= 0;
                        pixel_col <= 0;
                        state <= ST_SET_PAGE;
                    end
                end
                
                ST_SET_PAGE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; 
                        // El texto estará en la página 3 (centro de la pantalla)
                        drv_byte <= 8'hB8 | 8'h03; 
                        // Seleccionamos ambos chips para configurar la página simultáneamente
                        drv_cs1 <= 1'b1;
                        drv_cs2 <= 1'b1;
                        drv_start <= 1'b1;
                        return_state <= ST_SET_Y; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_SET_Y: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0;
                        // Chip Select dinámico por columna de píxel
                        drv_cs1 <= (abs_col < 7'd64) ? 1'b1 : 1'b0;
                        drv_cs2 <= (abs_col >= 7'd64) ? 1'b1 : 1'b0;
                        // Dirección Y local (0 a 63)
                        drv_byte <= 8'h40 | ((abs_col < 7'd64) ? abs_col : (abs_col - 7'd64)); 
                        drv_start <= 1'b1;
                        return_state <= ST_WRITE_DAT; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_WRITE_DAT: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b1;
                        // Mismos CS que configuramos en ST_SET_Y
                        drv_cs1 <= (abs_col < 7'd64) ? 1'b1 : 1'b0;
                        drv_cs2 <= (abs_col >= 7'd64) ? 1'b1 : 1'b0;
                        drv_byte <= (pixel_col == 5) ? 8'h00 : current_pixel_data;
                        drv_start <= 1'b1;
                        
                        if (pixel_col == 5) begin
                            pixel_col <= 3'd0;
                            if (char_idx == 5'd16) begin
                                char_idx <= 5'd0;
                                return_state <= ST_IDLE; // Terminó de imprimir la frase
                            end else begin
                                char_idx <= char_idx + 1'b1;
                                return_state <= ST_SET_Y; // Siempre va a ST_SET_Y para recalcular CS/Y
                            end
                        end else begin
                            pixel_col <= pixel_col + 1'b1;
                            return_state <= ST_SET_Y; // Siempre va a ST_SET_Y para la siguiente columna de píxeles
                        end
                        state <= ST_WAIT_DRV;
                    end
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
                                 char_idx <= 5'd0;
                                 pixel_col <= 3'd0;
                                 return_state <= ST_SET_PAGE; // Dibujar el peso de inmediato
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
                    drv_start <= 0;
                    if (drv_ready) state <= return_state;
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule