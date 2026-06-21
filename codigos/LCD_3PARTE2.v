// =============================================================================
// MÓDULO PRINCIPAL
// Entradas: clk (50MHz), entrada_a y entrada_b (4 bits cada una, desde SW)
// Salidas:  rs, en, rw, dat → van directamente a los pines de la LCD
// =============================================================================
module lcd_parte2(
    input        clk, // Reloj de 50MHz
    input  [3:0] entrada_a, // SW[3:0] → valor 0–15 para fila 1
    input  [3:0] entrada_b, // sW[7:4] → valor 0–15 para fila 2
    output       rs, //Register select: 0= comando, 1=dato 
    output       en, //Enable: pulso que le dice a la LCD "lee ahora"
    output       rw, //Read/write: siempre 0 (solo escribimos)
    output [7:0] dat //Bus de datos: el byte que enviamos a la LCD
);

// =============================================================================
// PARÁMETROS DE TIEMPO
// La LCD es lenta comparada con el FPGA (50MHz = 20ns por ciclo).
// Necesitamos esperar entre comandos. Cada localparam es un número de ciclos
// que equivale al tiempo real indicado.
//
//   DELAY_40MS  = 2,000,000 ciclos × 20ns = 40ms  → espera inicial al encender
//   DELAY_5MS   =   250,000 ciclos × 20ns =  5ms  → tras clear/reset
//   DELAY_100US =     5,000 ciclos × 20ns =100µs  → entre comandos de init
//   DELAY_2MS   =   100,000 ciclos × 20ns =  2ms  → entre comandos normales
//   EN_HIGH_T   =     1,250 ciclos × 20ns = 25µs  → duración del pulso Enable
// =============================================================================
    
    localparam DELAY_40MS  = 21'd2_000_000;
    localparam DELAY_5MS   = 21'd250_000;
    localparam DELAY_100US = 21'd5_000;
    localparam DELAY_2MS   = 21'd100_000;
    localparam EN_HIGH_T   = 11'd1_250;

    reg        rs_r, en_r; //
    reg [7:0]  dat_r;
    reg [5:0]  state;
    reg        busy;
    reg [20:0] delay_cnt;
    reg [10:0] en_cnt;
    reg [20:0] wait_time;
    reg [8:0]  lcd_cmd;

    // -------------------------------------------------------------------------
    // CONVERSOR BIN→ASCII (0–15, dos dígitos)
    // -------------------------------------------------------------------------
    reg [7:0] a_dec_ascii, a_uni_ascii;
    reg [7:0] b_dec_ascii, b_uni_ascii;

    // -------------------------------------------------------------------------
    // ETIQUETA DE RANGO: 4 caracteres ASCII
    //   0–4   → "BAJO" 
    //   5–10  → "MEDI"  (la 'O' va aparte para no sobrepasar col 15)
    //   11–15 → "ALTO"
    //
    // Usamos 4 registros por canal para los 4 chars de la etiqueta
    // -------------------------------------------------------------------------
    reg [7:0] a_r0, a_r1, a_r2, a_r3;  // 4 chars etiqueta canal A
    reg [7:0] b_r0, b_r1, b_r2, b_r3;  // 4 chars etiqueta canal B

    always @(*) begin
        // --- Canal A ---
        a_dec_ascii = (entrada_a / 10) + 8'h30;
        a_uni_ascii = (entrada_a % 10) + 8'h30;

        if (entrada_a <= 4) begin
            a_r0 = 8'h42; // 'B'
            a_r1 = 8'h41; // 'A'
            a_r2 = 8'h4A; // 'J'
            a_r3 = 8'h4F; // 'O'
        end else if (entrada_a <= 10) begin
            a_r0 = 8'h4D; // 'M'
            a_r1 = 8'h45; // 'E'
            a_r2 = 8'h44; // 'D'
            a_r3 = 8'h49; // 'I'
        end else begin
            a_r0 = 8'h41; // 'A'
            a_r1 = 8'h4C; // 'L'
            a_r2 = 8'h54; // 'T'
            a_r3 = 8'h4F; // 'O'
        end

        // --- Canal B ---
        b_dec_ascii = (entrada_b / 10) + 8'h30;
        b_uni_ascii = (entrada_b % 10) + 8'h30;

        if (entrada_b <= 4) begin
            b_r0 = 8'h42; b_r1 = 8'h41; b_r2 = 8'h4A; b_r3 = 8'h4F; // BAJO
        end else if (entrada_b <= 10) begin
            b_r0 = 8'h4D; b_r1 = 8'h45; b_r2 = 8'h44; b_r3 = 8'h49; // MEDI
        end else begin
            b_r0 = 8'h41; b_r1 = 8'h4C; b_r2 = 8'h54; b_r3 = 8'h4F; // ALTO
        end
    end

    assign en  = en_r;
    assign rs  = rs_r;
    assign dat = dat_r;
    assign rw  = 1'b0;

    // -------------------------------------------------------------------------
    // FSM
    // Layout fila 1: "Temp A: DD BAJO"  → 15 chars (col 0–14)
    //                 0123456789...
    //   "Temp A: " → cols 0–7  (8 chars, texto fijo)
    //   "DD"       → cols 8–9  (2 dígitos dinámicos)
    //   " "        → col  10   (espacio separador)
    //   "BAJO/MEDI/ALTO" → cols 11–14 (4 chars dinámicos)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!busy) begin
            busy      <= 1'b1;
            delay_cnt <= 21'd0;
            en_cnt    <= 11'd0;
            en_r      <= 1'b0;

            case (state)
                // =============================================================
                // INICIALIZACIÓN
                // =============================================================
                6'd0: begin lcd_cmd<={1'b0,8'h30}; wait_time<=DELAY_40MS;  state<=6'd1; end
                6'd1: begin lcd_cmd<={1'b0,8'h30}; wait_time<=DELAY_5MS;   state<=6'd2; end
                6'd2: begin lcd_cmd<={1'b0,8'h30}; wait_time<=DELAY_100US; state<=6'd3; end
                6'd3: begin lcd_cmd<={1'b0,8'h38}; wait_time<=DELAY_2MS;   state<=6'd4; end
                6'd4: begin lcd_cmd<={1'b0,8'h08}; wait_time<=DELAY_2MS;   state<=6'd5; end
                6'd5: begin lcd_cmd<={1'b0,8'h01}; wait_time<=DELAY_5MS;   state<=6'd6; end
                6'd6: begin lcd_cmd<={1'b0,8'h06}; wait_time<=DELAY_2MS;   state<=6'd7; end
                6'd7: begin lcd_cmd<={1'b0,8'h0C}; wait_time<=DELAY_2MS;   state<=6'd8; end

                // =============================================================
                // FILA 1 — TEXTO ESTÁTICO: "Temp A: " (cols 0–7)
                // =============================================================
                6'd8:  begin lcd_cmd<={1'b1,8'h54}; wait_time<=DELAY_2MS; state<=6'd9;  end // 'T'
                6'd9:  begin lcd_cmd<={1'b1,8'h65}; wait_time<=DELAY_2MS; state<=6'd10; end // 'e'
                6'd10: begin lcd_cmd<={1'b1,8'h6D}; wait_time<=DELAY_2MS; state<=6'd11; end // 'm'
                6'd11: begin lcd_cmd<={1'b1,8'h70}; wait_time<=DELAY_2MS; state<=6'd12; end // 'p'
                6'd12: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd13; end // ' '
                6'd13: begin lcd_cmd<={1'b1,8'h41}; wait_time<=DELAY_2MS; state<=6'd14; end // 'A'
                6'd14: begin lcd_cmd<={1'b1,8'h3A}; wait_time<=DELAY_2MS; state<=6'd15; end // ':'
                6'd15: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd16; end // ' '

                // FILA 1 — DÍGITOS DINÁMICOS en cols 8–9
                6'd16: begin lcd_cmd<={1'b1,a_dec_ascii}; wait_time<=DELAY_2MS; state<=6'd17; end
                6'd17: begin lcd_cmd<={1'b1,a_uni_ascii}; wait_time<=DELAY_2MS; state<=6'd18; end

                // FILA 1 — SEPARADOR + ETIQUETA de rango en cols 10–14
                6'd18: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd19; end // ' '
                6'd19: begin lcd_cmd<={1'b1,a_r0};   wait_time<=DELAY_2MS; state<=6'd20; end
                6'd20: begin lcd_cmd<={1'b1,a_r1};   wait_time<=DELAY_2MS; state<=6'd21; end
                6'd21: begin lcd_cmd<={1'b1,a_r2};   wait_time<=DELAY_2MS; state<=6'd22; end
                6'd22: begin lcd_cmd<={1'b1,a_r3};   wait_time<=DELAY_2MS; state<=6'd23; end

                // =============================================================
                // CAMBIO A FILA 2 → 0xC0
                // =============================================================
                6'd23: begin lcd_cmd<={1'b0,8'hC0}; wait_time<=DELAY_2MS; state<=6'd24; end

                // =============================================================
                // FILA 2 — TEXTO ESTÁTICO: "Temp B: " (cols 0–7)
                // =============================================================
                6'd24: begin lcd_cmd<={1'b1,8'h54}; wait_time<=DELAY_2MS; state<=6'd25; end // 'T'
                6'd25: begin lcd_cmd<={1'b1,8'h65}; wait_time<=DELAY_2MS; state<=6'd26; end // 'e'
                6'd26: begin lcd_cmd<={1'b1,8'h6D}; wait_time<=DELAY_2MS; state<=6'd27; end // 'm'
                6'd27: begin lcd_cmd<={1'b1,8'h70}; wait_time<=DELAY_2MS; state<=6'd28; end // 'p'
                6'd28: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd29; end // ' '
                6'd29: begin lcd_cmd<={1'b1,8'h42}; wait_time<=DELAY_2MS; state<=6'd30; end // 'B'
                6'd30: begin lcd_cmd<={1'b1,8'h3A}; wait_time<=DELAY_2MS; state<=6'd31; end // ':'
                6'd31: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd32; end // ' '

                // FILA 2 — DÍGITOS DINÁMICOS en cols 8–9
                6'd32: begin lcd_cmd<={1'b1,b_dec_ascii}; wait_time<=DELAY_2MS; state<=6'd33; end
                6'd33: begin lcd_cmd<={1'b1,b_uni_ascii}; wait_time<=DELAY_2MS; state<=6'd34; end

                // FILA 2 — SEPARADOR + ETIQUETA de rango en cols 10–14
                6'd34: begin lcd_cmd<={1'b1,8'h20}; wait_time<=DELAY_2MS; state<=6'd35; end // ' '
                6'd35: begin lcd_cmd<={1'b1,b_r0};   wait_time<=DELAY_2MS; state<=6'd36; end
                6'd36: begin lcd_cmd<={1'b1,b_r1};   wait_time<=DELAY_2MS; state<=6'd37; end
                6'd37: begin lcd_cmd<={1'b1,b_r2};   wait_time<=DELAY_2MS; state<=6'd38; end
                6'd38: begin lcd_cmd<={1'b1,b_r3};   wait_time<=DELAY_2MS; state<=6'd39; end

                // =============================================================
                // REGRESO AL INICIO DE REFRESCO (salta init)
                // =============================================================
                6'd39: begin lcd_cmd<={1'b0,8'h80}; wait_time<=DELAY_2MS; state<=6'd8; end

                default: begin busy <= 1'b0; end
            endcase

        end else begin
            if (delay_cnt < wait_time) begin
                delay_cnt <= delay_cnt + 21'd1;
                en_r      <= 1'b0;
                rs_r      <= lcd_cmd[8];
                dat_r     <= lcd_cmd[7:0];
            end
            else if (en_cnt < EN_HIGH_T) begin
                en_r   <= 1'b1;
                en_cnt <= en_cnt + 11'd1;
            end
            else begin
                en_r <= 1'b0;
                busy <= 1'b0;
            end
        end
    end

endmodule