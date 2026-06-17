`timescale 1ns / 1ps

module sensor_de_sonido #(
    parameter [25:0] TICKS_HOLD = 26'd50000000 // 1 segundo completo a 50 MHz (Tiempo de sostenimiento del estado activo)
)(
    input wire clk_50mhz,
    input wire rst_n,
    input wire sound_raw,        // Pin físico del sensor LM393
    output reg sound_active,    // Estado filtrado (Activo en alto: 1 = Sonido, 0 = Silencio)
    output reg sound_pulse       // Pulso de 1 ciclo clk_50mhz al iniciar la detección de sonido
);

    // 1. Sincronizador de 2 etapas para evitar metaestabilidad
    reg sound_s0, sound_s1;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            sound_s0 <= 1'b1;
            sound_s1 <= 1'b1;
        end else begin
            sound_s0 <= sound_raw;
            sound_s1 <= sound_s0;
        end
    end

    // 2. Extractor de Envolvente por Detección de Transición (Cualquier Flanco)
    // Al detectar cualquier flanco (subida o bajada) en la señal sincronizada (toggles del micrófono),
    // recargamos el temporizador de sostenimiento por 1 segundo.
    reg [25:0] hold_timer;
    reg last_sound_active;

    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) begin
            hold_timer        <= 26'd0;
            sound_active      <= 1'b0;
            last_sound_active <= 1'b0;
            sound_pulse       <= 1'b0;
        end else begin
            last_sound_active <= sound_active;
            sound_pulse       <= 1'b0; // Pulso en 0 por defecto

            // Si detectamos cualquier cambio (transición) en la entrada filtrada
            if (sound_s0 != sound_s1) begin
                hold_timer   <= TICKS_HOLD;
                sound_active <= 1'b1; // Activo en alto inmediatamente
            end else begin
                if (hold_timer > 26'd0) begin
                    hold_timer   <= hold_timer - 1'b1;
                    sound_active <= 1'b1;
                end else begin
                    sound_active <= 1'b0; // Retorna a inactivo tras 1 segundo sin transiciones
                end
            end

            // Generar un único pulso de 1 ciclo de reloj en el flanco de subida de sound_active
            if (sound_active && !last_sound_active) begin
                sound_pulse <= 1'b1;
            end
        end
    end

endmodule
