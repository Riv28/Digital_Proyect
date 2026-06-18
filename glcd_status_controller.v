`timescale 1ns / 1ps

module glcd_status_controller (
    input wire clk_50mhz,
    input wire clk_en_1mhz,
    input wire rst_n,
    
    // --- Entradas de Monitoreo ---
    input wire sound_active,
    input wire [15:0] weight_bcd,
    input wire weight_sign,
    input wire motor_active,
    input wire [15:0] cooldown_ticks,
    input wire cooldown_active,
    input wire [2:0] fsm_state,
    
    // --- Interfaz con el GLCD Driver ---
    output reg drv_start,
    output reg drv_rs,
    output reg drv_cs1,
    output reg drv_cs2,
    output reg [7:0] drv_byte,
    input wire drv_ready
);

    // Registros locales para almacenar de forma estable las entradas de monitoreo
    reg sound_active_reg;
    reg [15:0] weight_bcd_reg;
    reg weight_sign_reg;
    reg motor_active_reg;
    reg [15:0] cooldown_ticks_reg;
    reg cooldown_active_reg;
    reg [2:0] fsm_state_reg;
    reg pending_clear; // Para detectar cambios de estado y limpiar pantalla
    
    reg refresh_req;
    reg [16:0] refresh_timer; // 100,000 ciclos a 1 MHz = 100 ms

    // Actualización de los registros de entrada en el dominio de 1 MHz
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            sound_active_reg    <= 1'b0;
            weight_bcd_reg      <= 16'd0;
            weight_sign_reg     <= 1'b0;
            motor_active_reg    <= 1'b0;
            cooldown_ticks_reg  <= 16'd0;
            cooldown_active_reg <= 1'b0;
            fsm_state_reg       <= 3'd0;
            pending_clear       <= 1'b0;
        end else if (clk_en_1mhz) begin
            // Detectar cambios de estado en cualquier momento para forzar borrado
            if (fsm_state != fsm_state_reg) begin
                pending_clear <= 1'b1;
            end else if (state == ST_CLEAR_PAGE) begin
                pending_clear <= 1'b0;
            end

            if (state == ST_IDLE) begin
                sound_active_reg    <= sound_active;
                weight_bcd_reg      <= weight_bcd;
                weight_sign_reg     <= weight_sign;
                motor_active_reg    <= motor_active;
                cooldown_ticks_reg  <= cooldown_ticks;
                cooldown_active_reg <= cooldown_active;
                fsm_state_reg       <= fsm_state;
            end
        end
    end

    // Decodificación de dígitos para el cooldown
    wire [3:0] val_ones  = cooldown_ticks_reg % 4'd10;
    wire [3:0] val_tens  = (cooldown_ticks_reg / 7'd10) % 4'd10;
    wire [3:0] val_hunds = (cooldown_ticks_reg / 7'd100) % 4'd10;
    wire [3:0] val_thous = (cooldown_ticks_reg / 10'd1000) % 4'd10;

    // Columna absoluta en la pantalla de 128x64 (0 a 127)
    wire [6:0] abs_col = ({2'b00, char_idx} * 7'd6) + {4'b0000, pixel_col};

    // Máquina de estados
    reg [4:0] state;
    reg [4:0] return_state;
    reg [15:0] init_timer;
    
    reg [2:0] line_idx;  // 5 líneas (0 a 4)
    reg [4:0] char_idx;  // 21 caracteres por línea (0 a 20)
    reg [2:0] pixel_col; // 6 columnas de píxeles por caracter (0 a 5)
    
    reg [5:0] clear_col;
    reg [2:0] page;
    reg initialized;
    
    wire [7:0] current_pixel_data;
    reg [7:0] char_code;

    // Decodificador de caracteres según la línea, el índice y el estado de la FSM
    always @(*) begin
        char_code = 8'h20; // Por defecto espacio
        case (line_idx)
            3'd0: begin // Línea 0 (Página 1)
                case (fsm_state_reg)
                    3'd0: begin // TODAVIA FALTA QUE
                        case (char_idx)
                            5'd0:  char_code = 8'h54; // 'T'
                            5'd1:  char_code = 8'h4F; // 'O'
                            5'd2:  char_code = 8'h44; // 'D'
                            5'd3:  char_code = 8'h41; // 'A'
                            5'd4:  char_code = 8'h56; // 'V'
                            5'd5:  char_code = 8'h49; // 'I'
                            5'd6:  char_code = 8'h41; // 'A'
                            5'd7:  char_code = 8'h20; // ' '
                            5'd8:  char_code = 8'h46; // 'F'
                            5'd9:  char_code = 8'h41; // 'A'
                            5'd10: char_code = 8'h4C; // 'L'
                            5'd11: char_code = 8'h54; // 'T'
                            5'd12: char_code = 8'h41; // 'A'
                            5'd13: char_code = 8'h20; // ' '
                            5'd14: char_code = 8'h51; // 'Q'
                            5'd15: char_code = 8'h55; // 'U'
                            5'd16: char_code = 8'h45; // 'E'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd1: begin // ES MOMENTO QUE
                        case (char_idx)
                            5'd0:  char_code = 8'h45; // 'E'
                            5'd1:  char_code = 8'h53; // 'S'
                            5'd2:  char_code = 8'h20; // ' '
                            5'd3:  char_code = 8'h4D; // 'M'
                            5'd4:  char_code = 8'h4F; // 'O'
                            5'd5:  char_code = 8'h4D; // 'M'
                            5'd6:  char_code = 8'h45; // 'E'
                            5'd7:  char_code = 8'h4E; // 'N'
                            5'd8:  char_code = 8'h54; // 'T'
                            5'd9:  char_code = 8'h4F; // 'O'
                            5'd10: char_code = 8'h20; // ' '
                            5'd11: char_code = 8'h51; // 'Q'
                            5'd12: char_code = 8'h55; // 'U'
                            5'd13: char_code = 8'h45; // 'E'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd2: begin // TU COMIDA ESTA
                        case (char_idx)
                            5'd0:  char_code = 8'h54; // 'T'
                            5'd1:  char_code = 8'h55; // 'U'
                            5'd2:  char_code = 8'h20; // ' '
                            5'd3:  char_code = 8'h43; // 'C'
                            5'd4:  char_code = 8'h4F; // 'O'
                            5'd5:  char_code = 8'h4D; // 'M'
                            5'd6:  char_code = 8'h49; // 'I'
                            5'd7:  char_code = 8'h44; // 'D'
                            5'd8:  char_code = 8'h41; // 'A'
                            5'd9:  char_code = 8'h20; // ' '
                            5'd10: char_code = 8'h45; // 'E'
                            5'd11: char_code = 8'h53; // 'S'
                            5'd12: char_code = 8'h54; // 'T'
                            5'd13: char_code = 8'h41; // 'A'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd3: begin // ESTA CASI LISTO
                        case (char_idx)
                            5'd0:  char_code = 8'h45; // 'E'
                            5'd1:  char_code = 8'h53; // 'S'
                            5'd2:  char_code = 8'h54; // 'T'
                            5'd3:  char_code = 8'h41; // 'A'
                            5'd4:  char_code = 8'h20; // ' '
                            5'd5:  char_code = 8'h43; // 'C'
                            5'd6:  char_code = 8'h41; // 'A'
                            5'd7:  char_code = 8'h53; // 'S'
                            5'd8:  char_code = 8'h49; // 'I'
                            5'd9:  char_code = 8'h20; // ' '
                            5'd10: char_code = 8'h4C; // 'L'
                            5'd11: char_code = 8'h49; // 'I'
                            5'd12: char_code = 8'h53; // 'S'
                            5'd13: char_code = 8'h54; // 'T'
                            5'd14: char_code = 8'h4F; // 'O'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd4: begin // ESTAMOS ESPERANDO QUE
                        case (char_idx)
                            5'd0:  char_code = 8'h45; // 'E'
                            5'd1:  char_code = 8'h53; // 'S'
                            5'd2:  char_code = 8'h54; // 'T'
                            5'd3:  char_code = 8'h41; // 'A'
                            5'd4:  char_code = 8'h4D; // 'M'
                            5'd5:  char_code = 8'h4F; // 'O'
                            5'd6:  char_code = 8'h53; // 'S'
                            5'd7:  char_code = 8'h20; // ' '
                            5'd8:  char_code = 8'h45; // 'E'
                            5'd9:  char_code = 8'h53; // 'S'
                            5'd10: char_code = 8'h50; // 'P'
                            5'd11: char_code = 8'h45; // 'E'
                            5'd12: char_code = 8'h52; // 'R'
                            5'd13: char_code = 8'h41; // 'A'
                            5'd14: char_code = 8'h4E; // 'N'
                            5'd15: char_code = 8'h44; // 'D'
                            5'd16: char_code = 8'h4F; // 'O'
                            5'd17: char_code = 8'h20; // ' '
                            5'd18: char_code = 8'h51; // 'Q'
                            5'd19: char_code = 8'h55; // 'U'
                            5'd20: char_code = 8'h45; // 'E'
                            default: char_code = 8'h20;
                        endcase
                    end
                    default: char_code = 8'h20;
                endcase
            end
            
            3'd1: begin // Línea 1 (Página 3)
                case (fsm_state_reg)
                    3'd0, 3'd1: begin // COMAS GATITO
                        case (char_idx)
                            5'd0:  char_code = 8'h43; // 'C'
                            5'd1:  char_code = 8'h4F; // 'O'
                            5'd2:  char_code = 8'h4D; // 'M'
                            5'd3:  char_code = 8'h41; // 'A'
                            5'd4:  char_code = 8'h53; // 'S'
                            5'd5:  char_code = 8'h20; // ' '
                            5'd6:  char_code = 8'h47; // 'G'
                            5'd7:  char_code = 8'h41; // 'A'
                            5'd8:  char_code = 8'h54; // 'T'
                            5'd9:  char_code = 8'h49; // 'I'
                            5'd10: char_code = 8'h54; // 'T'
                            5'd11: char_code = 8'h4F; // 'O'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd2: begin // CASI LISTA :)
                        case (char_idx)
                            5'd0:  char_code = 8'h43; // 'C'
                            5'd1:  char_code = 8'h41; // 'A'
                            5'd2:  char_code = 8'h53; // 'S'
                            5'd3:  char_code = 8'h49; // 'I'
                            5'd4:  char_code = 8'h20; // ' '
                            5'd5:  char_code = 8'h4C; // 'L'
                            5'd6:  char_code = 8'h49; // 'I'
                            5'd7:  char_code = 8'h53; // 'S'
                            5'd8:  char_code = 8'h54; // 'T'
                            5'd9:  char_code = 8'h41; // 'A'
                            5'd10: char_code = 8'h20; // ' '
                            5'd11: char_code = 8'h3A; // ':'
                            5'd12: char_code = 8'h29; // ')'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd3: begin // PARA QUE PUEDAS COMER
                        case (char_idx)
                            5'd0:  char_code = 8'h50; // 'P'
                            5'd1:  char_code = 8'h41; // 'A'
                            5'd2:  char_code = 8'h52; // 'R'
                            5'd3:  char_code = 8'h41; // 'A'
                            5'd4:  char_code = 8'h20; // ' '
                            5'd5:  char_code = 8'h51; // 'Q'
                            5'd6:  char_code = 8'h55; // 'U'
                            5'd7:  char_code = 8'h45; // 'E'
                            5'd8:  char_code = 8'h20; // ' '
                            5'd9:  char_code = 8'h50; // 'P'
                            5'd10: char_code = 8'h55; // 'U'
                            5'd11: char_code = 8'h45; // 'E'
                            5'd12: char_code = 8'h44; // 'D'
                            5'd13: char_code = 8'h41; // 'A'
                            5'd14: char_code = 8'h53; // 'S'
                            5'd15: char_code = 8'h20; // ' '
                            5'd16: char_code = 8'h43; // 'C'
                            5'd17: char_code = 8'h4F; // 'O'
                            5'd18: char_code = 8'h4D; // 'M'
                            5'd19: char_code = 8'h45; // 'E'
                            5'd20: char_code = 8'h52; // 'R'
                            default: char_code = 8'h20;
                        endcase
                    end
                    3'd4: begin // TERMINES DE COMER
                        case (char_idx)
                            5'd0:  char_code = 8'h54; // 'T'
                            5'd1:  char_code = 8'h45; // 'E'
                            5'd2:  char_code = 8'h52; // 'R'
                            5'd3:  char_code = 8'h4D; // 'M'
                            5'd4:  char_code = 8'h49; // 'I'
                            5'd5:  char_code = 8'h4E; // 'N'
                            5'd6:  char_code = 8'h45; // 'E'
                            5'd7:  char_code = 8'h53; // 'S'
                            5'd8:  char_code = 8'h20; // ' '
                            5'd9:  char_code = 8'h44; // 'D'
                            5'd10: char_code = 8'h45; // 'E'
                            5'd11: char_code = 8'h20; // ' '
                            5'd12: char_code = 8'h43; // 'C'
                            5'd13: char_code = 8'h4F; // 'O'
                            5'd14: char_code = 8'h4D; // 'M'
                            5'd15: char_code = 8'h45; // 'E'
                            5'd16: char_code = 8'h52; // 'R'
                            default: char_code = 8'h20;
                        endcase
                    end
                    default: char_code = 8'h20;
                endcase
            end
            
            3'd2: begin // Línea 2 (Página 5 para otros, Página 3 para ST_COOLDOWN)
                case (fsm_state_reg)
                    3'd2, 3'd3: begin // PESO:       [valor] g
                        case (char_idx)
                            5'd0:  char_code = 8'h50; // 'P'
                            5'd1:  char_code = 8'h45; // 'E'
                            5'd2:  char_code = 8'h53; // 'S'
                            5'd3:  char_code = 8'h4F; // 'O'
                            5'd4:  char_code = 8'h3A; // ':'
                            5'd5:  char_code = 8'h20;
                            5'd6:  char_code = 8'h20;
                            5'd7:  char_code = 8'h20;
                            5'd8:  char_code = 8'h20;
                            5'd9:  char_code = 8'h20;
                            default: begin
                                case (char_idx)
                                    5'd10: char_code = weight_sign_reg ? 8'h2D : 8'h20; // '-' o ' '
                                    5'd11: char_code = {4'b0011, weight_bcd_reg[15:12]}; // Miles
                                    5'd12: char_code = {4'b0011, weight_bcd_reg[11:8]};  // Centenas
                                    5'd13: char_code = {4'b0011, weight_bcd_reg[7:4]};   // Decenas
                                    5'd14: char_code = {4'b0011, weight_bcd_reg[3:0]};   // Unidades
                                    5'd15: char_code = 8'h20; // Espacio
                                    5'd16: char_code = 8'h67; // 'g'
                                    default: char_code = 8'h20;
                                endcase
                            end
                        endcase
                    end
                    3'd4: begin // GATITO PARA QUE ESTES
                        case (char_idx)
                            5'd0:  char_code = 8'h47; // 'G'
                            5'd1:  char_code = 8'h41; // 'A'
                            5'd2:  char_code = 8'h54; // 'T'
                            5'd3:  char_code = 8'h49; // 'I'
                            5'd4:  char_code = 8'h54; // 'T'
                            5'd5:  char_code = 8'h4F; // 'O'
                            5'd6:  char_code = 8'h20; // ' '
                            5'd7:  char_code = 8'h50; // 'P'
                            5'd8:  char_code = 8'h41; // 'A'
                            5'd9:  char_code = 8'h52; // 'R'
                            5'd10: char_code = 8'h41; // 'A'
                            5'd11: char_code = 8'h20; // ' '
                            5'd12: char_code = 8'h51; // 'Q'
                            5'd13: char_code = 8'h55; // 'U'
                            5'd14: char_code = 8'h45; // 'E'
                            5'd15: char_code = 8'h20; // ' '
                            5'd16: char_code = 8'h45; // 'E'
                            5'd17: char_code = 8'h53; // 'S'
                            5'd18: char_code = 8'h54; // 'T'
                            5'd19: char_code = 8'h45; // 'E'
                            5'd20: char_code = 8'h53; // 'S'
                            default: char_code = 8'h20;
                        endcase
                    end
                    default: char_code = 8'h20;
                endcase
            end
            
            3'd3: begin // Línea 3 (Página 7 para otros, Página 5 para ST_COOLDOWN)
                case (fsm_state_reg)
                    3'd4: begin // SANO:       [tiempo] s
                        case (char_idx)
                            5'd0:  char_code = 8'h53; // 'S'
                            5'd1:  char_code = 8'h41; // 'A'
                            5'd2:  char_code = 8'h4E; // 'N'
                            5'd3:  char_code = 8'h4F; // 'O'
                            5'd4:  char_code = 8'h3A; // ':'
                            5'd5:  char_code = 8'h20;
                            5'd6:  char_code = 8'h20;
                            5'd7:  char_code = 8'h20;
                            5'd8:  char_code = 8'h20;
                            5'd9:  char_code = 8'h20;
                            default: begin
                                case (char_idx)
                                    5'd10: char_code = (cooldown_ticks_reg >= 1000) ? {4'b0011, val_thous} : 8'h20;
                                    5'd11: char_code = (cooldown_ticks_reg >= 100)  ? {4'b0011, val_hunds} : 8'h20;
                                    5'd12: char_code = (cooldown_ticks_reg >= 10)   ? {4'b0011, val_tens}  : 8'h20;
                                    5'd13: char_code = {4'b0011, val_ones};  // Unidades
                                    5'd14: char_code = 8'h20; // Espacio
                                    5'd15: char_code = 8'h73; // 's'
                                    default: char_code = 8'h20;
                                endcase
                            end
                        endcase
                    end
                    default: char_code = 8'h20;
                endcase
            end

            3'd4: begin // Línea 4 (Página 6 para ST_COOLDOWN)
                case (fsm_state_reg)
                    3'd4: begin // PESO:       [valor] g
                        case (char_idx)
                            5'd0:  char_code = 8'h50; // 'P'
                            5'd1:  char_code = 8'h45; // 'E'
                            5'd2:  char_code = 8'h53; // 'S'
                            5'd3:  char_code = 8'h4F; // 'O'
                            5'd4:  char_code = 8'h3A; // ':'
                            5'd5:  char_code = 8'h20;
                            5'd6:  char_code = 8'h20;
                            5'd7:  char_code = 8'h20;
                            5'd8:  char_code = 8'h20;
                            5'd9:  char_code = 8'h20;
                            default: begin
                                case (char_idx)
                                    5'd10: char_code = weight_sign_reg ? 8'h2D : 8'h20; // '-' o ' '
                                    5'd11: char_code = {4'b0011, weight_bcd_reg[15:12]}; // Miles
                                    5'd12: char_code = {4'b0011, weight_bcd_reg[11:8]};  // Centenas
                                    5'd13: char_code = {4'b0011, weight_bcd_reg[7:4]};   // Decenas
                                    5'd14: char_code = {4'b0011, weight_bcd_reg[3:0]};   // Unidades
                                    5'd15: char_code = 8'h20; // Espacio
                                    5'd16: char_code = 8'h67; // 'g'
                                    default: char_code = 8'h20;
                                endcase
                            end
                        endcase
                    end
                    default: char_code = 8'h20;
                endcase
            end
            
            default: char_code = 8'h20;
        endcase
    end

    // Instancia de la memoria ROM
    font_rom u_font (
        .char_code(char_code),
        .col(pixel_col),
        .pixel_data(current_pixel_data)
    );

    // Estados de la máquina
    localparam ST_INIT_WAIT   = 5'd0;
    localparam ST_DISP_ON     = 5'd1;
    localparam ST_START_LN    = 5'd2;
    localparam ST_IDLE        = 5'd3;
    localparam ST_SET_PAGE    = 5'd4;
    localparam ST_SET_Y       = 5'd5;
    localparam ST_WRITE_DAT   = 5'd6;
    localparam ST_WAIT_DRV    = 5'd7;
    localparam ST_CLEAR_PAGE  = 5'd8;
    localparam ST_CLEAR_Y     = 5'd9;
    localparam ST_CLEAR_WRITE = 5'd10;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_INIT_WAIT;
            init_timer   <= 16'd0; 
            char_idx     <= 5'd0; 
            line_idx     <= 2'd0;
            pixel_col    <= 3'd0; 
            drv_start    <= 1'b0;
            drv_rs       <= 1'b0; 
            drv_cs1      <= 1'b0; 
            drv_cs2      <= 1'b0; 
            drv_byte     <= 8'h00;
            return_state <= ST_INIT_WAIT;
            clear_col    <= 6'd0;
            page         <= 3'd0;
            initialized  <= 1'b0;
            refresh_timer <= 17'd0;
            refresh_req   <= 1'b1;
        end else if (clk_en_1mhz) begin
            if (initialized) begin
                if (refresh_timer == 17'd100000) begin // 100 ms
                    refresh_timer <= 17'd0;
                    refresh_req   <= 1'b1;
                end else begin
                    refresh_timer <= refresh_timer + 1'b1;
                end
            end
            
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
                    if (pending_clear) begin
                        // Al cambiar de estado de FSM, forzamos un borrado completo de la pantalla
                        page         <= 3'd0;
                        clear_col    <= 6'd0;
                        state        <= ST_CLEAR_PAGE;
                    end else if (refresh_req) begin
                        refresh_req <= 1'b0;
                        char_idx  <= 5'd0;
                        line_idx  <= 3'd0;
                        pixel_col <= 3'd0;
                        state     <= ST_SET_PAGE;
                    end
                end
                
                ST_SET_PAGE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; 
                        // Mapeo dinámico de la página física
                        if (fsm_state_reg == 3'd4) begin
                            // Para ST_COOLDOWN (5 líneas)
                            case (line_idx)
                                3'd0: drv_byte <= 8'hB8 | 8'h01; // Página 1: "ESTAMOS ESPERANDO QUE"
                                3'd1: drv_byte <= 8'hB8 | 8'h03; // Página 3: "TERMINES DE COMER"
                                3'd2: drv_byte <= 8'hB8 | 8'h05; // Página 5: "GATITO PARA QUE ESTES"
                                3'd3: drv_byte <= 8'hB8 | 8'h06; // Página 6: "SANO:       [tiempo] s"
                                3'd4: drv_byte <= 8'hB8 | 8'h07; // Página 7: "PESO:       [valor] g"
                                default: drv_byte <= 8'hB8 | 8'h01;
                            endcase
                        end else begin
                            // Para otros estados (máximo 4 líneas)
                            case (line_idx)
                                3'd0: drv_byte <= 8'hB8 | 8'h01; // Página 1
                                3'd1: drv_byte <= 8'hB8 | 8'h03; // Página 3
                                3'd2: drv_byte <= 8'hB8 | 8'h05; // Página 5
                                3'd3: drv_byte <= 8'hB8 | 8'h07; // Página 7
                                default: drv_byte <= 8'hB8 | 8'h01;
                            endcase
                        end
                        
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
                            if (char_idx == 5'd20) begin
                                char_idx <= 5'd0;
                                if ((fsm_state_reg == 3'd4 && line_idx == 3'd4) || (fsm_state_reg != 3'd4 && line_idx == 3'd3)) begin
                                    line_idx     <= 3'd0;
                                    return_state <= ST_IDLE; // Dibujó toda la pantalla, vuelve al reposo
                                end else begin
                                    line_idx     <= line_idx + 1'b1;
                                    return_state <= ST_SET_PAGE; // Va a la siguiente línea
                                end
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

                ST_CLEAR_PAGE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'hB8 | page; 
                        drv_start <= 1'b1;
                        return_state <= ST_CLEAR_Y; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_CLEAR_Y: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b0; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'h40;
                        drv_start <= 1'b1;
                        return_state <= ST_CLEAR_WRITE; state <= ST_WAIT_DRV;
                    end
                end
                
                ST_CLEAR_WRITE: begin
                    if (drv_ready) begin
                        drv_rs <= 1'b1; drv_cs1 <= 1'b1; drv_cs2 <= 1'b1;
                        drv_byte <= 8'h00; 
                        drv_start <= 1'b1;
                        
                        if (clear_col == 6'd63) begin
                            clear_col <= 6'd0;
                            if (page == 3'd7) begin
                                page         <= 3'd0;
                                char_idx     <= 5'd0;
                                line_idx     <= 3'd0;
                                pixel_col    <= 3'd0;
                                return_state <= ST_SET_PAGE; 
                            end else begin
                                page         <= page + 1'b1;
                                return_state <= ST_CLEAR_PAGE;
                            end
                        end else begin
                            clear_col    <= clear_col + 1'b1;
                            return_state <= ST_CLEAR_WRITE;
                        end
                        state <= ST_WAIT_DRV;
                    end
                end

                ST_WAIT_DRV: begin
                    drv_start <= 1'b0;
                    if (drv_ready) state <= return_state;
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
