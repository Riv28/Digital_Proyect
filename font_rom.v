module font_rom (
    input wire [7:0] char_code, // Código ASCII de la letra/número
    input wire [2:0] col,       // Columna del carácter (0 a 4)
    output reg [7:0] pixel_data
);
    always @(*) begin
        pixel_data = 8'h00; // Por defecto vacío
        if (col < 5) begin
            case (char_code)
                // Números (0-9)
                8'h30: case(col) 0: pixel_data=8'h3E; 1: pixel_data=8'h51; 2: pixel_data=8'h49; 3: pixel_data=8'h45; 4: pixel_data=8'h3E; endcase // '0'
                8'h31: case(col) 0: pixel_data=8'h00; 1: pixel_data=8'h42; 2: pixel_data=8'h7F; 3: pixel_data=8'h40; 4: pixel_data=8'h00; endcase // '1'
                8'h32: case(col) 0: pixel_data=8'h42; 1: pixel_data=8'h61; 2: pixel_data=8'h51; 3: pixel_data=8'h49; 4: pixel_data=8'h46; endcase // '2'
                8'h33: case(col) 0: pixel_data=8'h21; 1: pixel_data=8'h41; 2: pixel_data=8'h45; 3: pixel_data=8'h4B; 4: pixel_data=8'h31; endcase // '3'
                8'h34: case(col) 0: pixel_data=8'h18; 1: pixel_data=8'h14; 2: pixel_data=8'h12; 3: pixel_data=8'h7F; 4: pixel_data=8'h10; endcase // '4'
                8'h35: case(col) 0: pixel_data=8'h27; 1: pixel_data=8'h45; 2: pixel_data=8'h45; 3: pixel_data=8'h45; 4: pixel_data=8'h39; endcase // '5'
                8'h36: case(col) 0: pixel_data=8'h3C; 1: pixel_data=8'h4A; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h30; endcase // '6'
                8'h37: case(col) 0: pixel_data=8'h01; 1: pixel_data=8'h71; 2: pixel_data=8'h09; 3: pixel_data=8'h05; 4: pixel_data=8'h03; endcase // '7'
                8'h38: case(col) 0: pixel_data=8'h36; 1: pixel_data=8'h49; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h36; endcase // '8'
                8'h39: case(col) 0: pixel_data=8'h06; 1: pixel_data=8'h49; 2: pixel_data=8'h49; 3: pixel_data=8'h29; 4: pixel_data=8'h1E; endcase // '9'
                
                // Letras necesarias ("PESO: g") y signos
                8'h50: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h09; 2: pixel_data=8'h09; 3: pixel_data=8'h09; 4: pixel_data=8'h06; endcase // 'P'
                8'h45: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h49; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h41; endcase // 'E'
                8'h53: case(col) 0: pixel_data=8'h46; 1: pixel_data=8'h49; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h31; endcase // 'S'
                8'h4F: case(col) 0: pixel_data=8'h3E; 1: pixel_data=8'h41; 2: pixel_data=8'h41; 3: pixel_data=8'h41; 4: pixel_data=8'h3E; endcase // 'O'
                8'h67: case(col) 0: pixel_data=8'h98; 1: pixel_data=8'hA4; 2: pixel_data=8'hA4; 3: pixel_data=8'hA4; 4: pixel_data=8'h7C; endcase // 'g'
                8'h3A: case(col) 0: pixel_data=8'h00; 1: pixel_data=8'h36; 2: pixel_data=8'h36; 3: pixel_data=8'h00; 4: pixel_data=8'h00; endcase // ':'
                8'h2D: case(col) 0: pixel_data=8'h08; 1: pixel_data=8'h08; 2: pixel_data=8'h08; 3: pixel_data=8'h08; 4: pixel_data=8'h08; endcase // '-'
                
                // Nuevas letras para "ACTIVADO" y "DESACTIVADO"
                8'h41: case(col) 0: pixel_data=8'h7E; 1: pixel_data=8'h11; 2: pixel_data=8'h11; 3: pixel_data=8'h11; 4: pixel_data=8'h7E; endcase // 'A'
                8'h43: case(col) 0: pixel_data=8'h3E; 1: pixel_data=8'h41; 2: pixel_data=8'h41; 3: pixel_data=8'h41; 4: pixel_data=8'h22; endcase // 'C'
                8'h44: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h41; 2: pixel_data=8'h41; 3: pixel_data=8'h22; 4: pixel_data=8'h1C; endcase // 'D'
                8'h49: case(col) 0: pixel_data=8'h41; 1: pixel_data=8'h41; 2: pixel_data=8'h7F; 3: pixel_data=8'h41; 4: pixel_data=8'h41; endcase // 'I'
                8'h4C: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h40; 2: pixel_data=8'h40; 3: pixel_data=8'h40; 4: pixel_data=8'h40; endcase // 'L'
                8'h4D: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h02; 2: pixel_data=8'h0C; 3: pixel_data=8'h02; 4: pixel_data=8'h7F; endcase // 'M'
                8'h54: case(col) 0: pixel_data=8'h01; 1: pixel_data=8'h01; 2: pixel_data=8'h7F; 3: pixel_data=8'h01; 4: pixel_data=8'h01; endcase // 'T'
                8'h56: case(col) 0: pixel_data=8'h1F; 1: pixel_data=8'h20; 2: pixel_data=8'h40; 3: pixel_data=8'h20; 4: pixel_data=8'h1F; endcase // 'V'
                
                // Letras adicionales para el motor y timer (N, G, R, s)
                8'h4E: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h02; 2: pixel_data=8'h04; 3: pixel_data=8'h08; 4: pixel_data=8'h7F; endcase // 'N'
                8'h47: case(col) 0: pixel_data=8'h3E; 1: pixel_data=8'h41; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h7A; endcase // 'G'
                8'h52: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h09; 2: pixel_data=8'h19; 3: pixel_data=8'h29; 4: pixel_data=8'h46; endcase // 'R'
                8'h73: case(col) 0: pixel_data=8'h24; 1: pixel_data=8'h4A; 2: pixel_data=8'h4A; 3: pixel_data=8'h4A; 4: pixel_data=8'h30; endcase // 's'
                
                // Letras necesarias para nuevos estados (H, Q, U, B, (, ))
                8'h48: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h08; 2: pixel_data=8'h08; 3: pixel_data=8'h08; 4: pixel_data=8'h7F; endcase // 'H'
                8'h51: case(col) 0: pixel_data=8'h3E; 1: pixel_data=8'h41; 2: pixel_data=8'h51; 3: pixel_data=8'h21; 4: pixel_data=8'h5E; endcase // 'Q'
                8'h55: case(col) 0: pixel_data=8'h3F; 1: pixel_data=8'h40; 2: pixel_data=8'h40; 3: pixel_data=8'h40; 4: pixel_data=8'h3F; endcase // 'U'
                8'h42: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h49; 2: pixel_data=8'h49; 3: pixel_data=8'h49; 4: pixel_data=8'h36; endcase // 'B'
                8'h28: case(col) 0: pixel_data=8'h00; 1: pixel_data=8'h1C; 2: pixel_data=8'h22; 3: pixel_data=8'h41; 4: pixel_data=8'h00; endcase // '('
                8'h29: case(col) 0: pixel_data=8'h00; 1: pixel_data=8'h41; 2: pixel_data=8'h22; 3: pixel_data=8'h1C; 4: pixel_data=8'h00; endcase // ')'
                
                // Letras faltantes para completar el alfabeto en mayúsculas
                8'h46: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h09; 2: pixel_data=8'h09; 3: pixel_data=8'h09; 4: pixel_data=8'h01; endcase // 'F'
                8'h4A: case(col) 0: pixel_data=8'h20; 1: pixel_data=8'h40; 2: pixel_data=8'h41; 3: pixel_data=8'h3F; 4: pixel_data=8'h00; endcase // 'J'
                8'h4B: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h08; 2: pixel_data=8'h14; 3: pixel_data=8'h22; 4: pixel_data=8'h41; endcase // 'K'
                8'h57: case(col) 0: pixel_data=8'h7F; 1: pixel_data=8'h20; 2: pixel_data=8'h18; 3: pixel_data=8'h20; 4: pixel_data=8'h7F; endcase // 'W'
                8'h58: case(col) 0: pixel_data=8'h63; 1: pixel_data=8'h14; 2: pixel_data=8'h08; 3: pixel_data=8'h14; 4: pixel_data=8'h63; endcase // 'X'
                8'h59: case(col) 0: pixel_data=8'h07; 1: pixel_data=8'h08; 2: pixel_data=8'h78; 3: pixel_data=8'h08; 4: pixel_data=8'h07; endcase // 'Y'
                8'h5A: case(col) 0: pixel_data=8'h61; 1: pixel_data=8'h51; 2: pixel_data=8'h49; 3: pixel_data=8'h45; 4: pixel_data=8'h43; endcase // 'Z'
                
                8'h20: pixel_data=8'h00; // Espacio
                default: pixel_data=8'h00;
            endcase
        end
    end
endmodule